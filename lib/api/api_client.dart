import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class _CacheEntry {
  _CacheEntry(this.data, this.at);

  final dynamic data;
  final DateTime at;
}

/// 统一的 API 异常，页面层可以捕获并展示明确提示。
class GiteeApiException implements Exception {
  GiteeApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Gitee Open API v5 传输层：统一 URL 拼装、鉴权头、超时与错误映射。
/// [http.Client] 可注入，便于用 MockClient 编写测试。
class ApiClient {
  ApiClient({http.Client? client, String? token})
      : _client = client ?? http.Client(),
        _token = token;

  final http.Client _client;
  String? _token;
  void Function()? onUnauthorized;
  final Map<String, _CacheEntry> _ttlCache = {};
  final Map<String, Future<dynamic>> _pendingCacheRequests = {};
  int _cacheGeneration = 0;
  int _sessionGeneration = 0;

  static const String baseUrl = 'https://gitee.com/api/v5';

  void setToken(String? token) {
    if (_token == token) return;
    _token = token;
    _sessionGeneration++;
    clearCache();
  }

  String? get token => _token;
  int get sessionGeneration => _sessionGeneration;

  void clearCache() {
    // In-flight requests cannot be cancelled reliably across all clients.
    // A generation guard prevents an old-account response being cached after
    // a token switch or logout.
    _cacheGeneration++;
    _ttlCache.clear();
    _pendingCacheRequests.clear();
  }

  /// Invalidates cached resources on the same API path hierarchy as a write.
  /// Unrelated cached resources remain available, avoiding a global cache flush.
  void invalidateCacheForPath(String path) {
    // A write may race with an already-running GET. Invalidate the generation
    // for all in-flight reads so an old response cannot repopulate any cache;
    // completed unrelated entries remain untouched below.
    _cacheGeneration++;
    final normalizedPath = normalizeApiPath(path);
    _ttlCache.removeWhere((key, _) {
      final cachedPath = key.split('?').first;
      return cachedPath == normalizedPath ||
          cachedPath.startsWith('$normalizedPath/') ||
          normalizedPath.startsWith('$cachedPath/');
    });
    _pendingCacheRequests.removeWhere((key, _) {
      final cachedPath = key.split('?').first;
      return cachedPath == normalizedPath ||
          cachedPath.startsWith('$normalizedPath/') ||
          normalizedPath.startsWith('$cachedPath/');
    });
  }

  Map<String, String> headers({bool formEncoded = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': formEncoded
          ? 'application/x-www-form-urlencoded'
          : 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'token ${_token!}';
    }
    return headers;
  }

  static Uri buildUri(String path, {Map<String, String>? query}) {
    return Uri.parse('$baseUrl${normalizeApiPath(path)}')
        .replace(queryParameters: query);
  }

  static String enc(String value) => Uri.encodeComponent(value);

  static String encPath(String path) =>
      path.split('/').where((e) => e.isNotEmpty).map(enc).join('/');

  static String? decodeContent(dynamic content) {
    final raw = content?.toString() ?? '';
    if (raw.trim().isEmpty) return null;
    try {
      final normalized = raw.replaceAll(RegExp(r'\s'), '');
      return utf8.decode(base64Decode(normalized));
    } catch (_) {
      return null;
    }
  }

  static String normalizeApiPath(String path) =>
      path.startsWith('/') ? path : '/$path';

  static Map<String, String> paging(int page, int perPage) =>
      {'page': page.toString(), 'per_page': perPage.toString()};

  static Map<String, dynamic> asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw GiteeApiException('数据格式错误');
  }

  static List<dynamic> asList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final list = data['list'] ?? data['items'] ?? data['threads'];
      if (list is List) return list;
    }
    throw GiteeApiException('数据格式错误');
  }

  static Map<String, String> formBody(Object body) {
    if (body is! Map) {
      throw ArgumentError.value(body, 'body', '表单请求需要键值对数据');
    }
    return body.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool formEncoded = false,
  }) async {
    final normalizedMethod = method.toUpperCase();
    const supportedMethods = {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'};
    if (!supportedMethods.contains(normalizedMethod)) {
      throw ArgumentError.value(method, 'method', '不支持的 HTTP 方法');
    }
    final uri = buildUri(path, query: query);
    final session = _sessionGeneration;
    try {
      // 创建 Issue 与 PR 的官方接口要求使用表单编码，其余写请求保持 JSON。
      final requestHeaders = headers(formEncoded: formEncoded);
      final Object? requestBody;
      if (body == null) {
        requestBody = null;
      } else if (formEncoded) {
        requestBody = formBody(body);
      } else {
        requestBody = jsonEncode(body);
      }
      late final http.Response res;
      switch (normalizedMethod) {
        case 'GET':
          res = await _client.get(uri, headers: requestHeaders).timeout(
                const Duration(seconds: 20),
              );
          break;
        case 'POST':
          res = await _client
              .post(uri, headers: requestHeaders, body: requestBody)
              .timeout(const Duration(seconds: 20));
          break;
        case 'PUT':
          res = await _client
              .put(uri, headers: requestHeaders, body: requestBody)
              .timeout(const Duration(seconds: 20));
          break;
        case 'PATCH':
          res = await _client
              .patch(uri, headers: requestHeaders, body: requestBody)
              .timeout(const Duration(seconds: 20));
          break;
        case 'DELETE':
          res = await _client
              .delete(uri, headers: requestHeaders, body: requestBody)
              .timeout(const Duration(seconds: 20));
          break;
        default:
          throw StateError('Unsupported HTTP method: $normalizedMethod');
      }
      _checkSession(session);
      final result = _handleResponse(res);
      if (normalizedMethod != 'GET') {
        invalidateCacheForPath(path);
      }
      return result;
    } on TimeoutException {
      throw GiteeApiException('请求超时，请稍后重试');
    } on GiteeApiException {
      rethrow;
    } catch (_) {
      throw GiteeApiException('网络异常，请检查网络连接');
    }
  }

  /// GET 结果短期缓存（默认 30s），供仓库详情/README 等高频重读场景使用。
  Future<dynamic> requestCached(
    String path, {
    Map<String, String>? query,
    Duration ttl = const Duration(seconds: 30),
  }) async {
    final normalizedPath = normalizeApiPath(path);
    final normalizedQuery = query == null
        ? ''
        : (query.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
            .map((e) => '${Uri.encodeQueryComponent(e.key)}='
                '${Uri.encodeQueryComponent(e.value)}')
            .join('&');
    final key = '$normalizedPath?$normalizedQuery';
    final hit = _ttlCache[key];
    if (hit != null && DateTime.now().difference(hit.at) < ttl) {
      return hit.data;
    }
    final pending = _pendingCacheRequests[key];
    if (pending != null) return pending;

    // 超过 50 条整体清空，简单防内存膨胀；如需更细可改 LRU。
    if (_ttlCache.length >= 50) _ttlCache.clear();
    final generation = _cacheGeneration;
    late final Future<dynamic> future;
    future = () async {
      try {
        final data = await request('GET', normalizedPath, query: query);
        if (_cacheGeneration == generation) {
          _ttlCache[key] = _CacheEntry(data, DateTime.now());
        }
        return data;
      } finally {
        if (identical(_pendingCacheRequests[key], future)) {
          _pendingCacheRequests.remove(key);
        }
      }
    }();
    _pendingCacheRequests[key] = future;
    return future;
  }

  /// multipart/form-data 文件上传（如 Release 附件），复用统一的错误映射。
  Future<dynamic> uploadMultipart(
    String path, {
    Map<String, String>? query,
    required String fileField,
    required List<int> fileBytes,
    required String filename,
  }) async {
    final uri = buildUri(path, query: query);
    final session = _sessionGeneration;
    try {
      final request = http.MultipartRequest('POST', uri)
        ..headers['Accept'] = 'application/json'
        ..files.add(
          http.MultipartFile.fromBytes(fileField, fileBytes,
              filename: filename),
        );
      if (_token != null) {
        request.headers['Authorization'] = 'token ${_token!}';
      }
      final streamed =
          await _client.send(request).timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 60));
      _checkSession(session);
      final result = _handleResponse(res);
      invalidateCacheForPath(path);
      return result;
    } on TimeoutException {
      throw GiteeApiException('请求超时，请稍后重试');
    } on GiteeApiException {
      rethrow;
    } catch (_) {
      throw GiteeApiException('网络异常，请检查网络连接');
    }
  }

  void _checkSession(int session) {
    if (session != _sessionGeneration) {
      throw GiteeApiException('账号已切换，请重新加载');
    }
  }

  /// 统一处理 HTTP 响应：2xx 解析 JSON，其余映射为友好的 GiteeApiException。
  dynamic _handleResponse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    var detail = '';
    try {
      final errorBody = jsonDecode(utf8.decode(res.bodyBytes));
      if (errorBody is Map && errorBody['message'] != null) {
        detail = '（${errorBody['message']}）';
      }
    } catch (_) {}
    var message = '请求失败（${res.statusCode}）';
    if (res.statusCode == 401) {
      message = '令牌无效或已过期，请重新登录';
      setToken(null);
      onUnauthorized?.call();
    } else if (res.statusCode == 403) {
      message = '没有权限访问该资源';
    } else if (res.statusCode == 404) {
      message = '资源不存在或已删除';
    } else if (res.statusCode == 429) {
      message = '请求过于频繁，请稍后重试';
    }
    throw GiteeApiException('$message$detail', res.statusCode);
  }
}
