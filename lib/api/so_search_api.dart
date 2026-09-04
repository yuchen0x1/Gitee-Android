import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/repo.dart';
import 'api_client.dart';

/// so.gitee.com（Indexea）仓库搜索客户端。
///
/// Gitee Open API v5 的 /search/repositories 存在服务端已知问题，
/// 即使令牌有效也常返回空数组（见 Gitee Feedback IKBZVY/ICCSIY），
/// 因此仓库搜索直接对接 Gitee 网页搜索同款数据源，匿名可访问。
class SoSearchApi {
  SoSearchApi({http.Client? client}) : _client = client ?? http.Client();

  static final SoSearchApi shared = SoSearchApi();

  static const _widgetIdent = 'wong1slagnlmzwvsu5ya';
  static const _baseUrl = 'https://so.gitee.com/v1';
  static const _timeout = Duration(seconds: 15);

  final http.Client _client;

  /// 搜索仓库，返回与 [Repo] 兼容的结果列表。
  ///
  /// [from] 为结果偏移量（分页用），[size] 为单页条数。
  Future<List<Repo>> searchRepos(
    String keyword, {
    int from = 0,
    int size = 30,
  }) async {
    final uri = Uri.parse('$_baseUrl/search/widget/$_widgetIdent').replace(
      queryParameters: {
        'q': keyword,
        'from': from.clamp(0, 1 << 31).toString(),
        'size': size.clamp(1, 100).toString(),
      },
    );
    late final http.Response res;
    try {
      res = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
    } catch (_) {
      throw GiteeApiException('网页搜索请求失败，请检查网络连接');
    }
    if (res.statusCode != 200) {
      throw GiteeApiException('网页搜索请求失败（${res.statusCode}）');
    }
    final dynamic data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw GiteeApiException('网页搜索响应解析失败');
    }
    final hits = _hitsOf(data);
    return hits.map(_repoOf).toList();
  }

  List<dynamic> _hitsOf(dynamic data) {
    if (data is Map) {
      final hits = data['hits'];
      if (hits is Map && hits['hits'] is List) return hits['hits'] as List;
      if (hits is List) return hits;
    }
    throw GiteeApiException('网页搜索响应格式错误');
  }

  /// Indexea 的字段值统一是数组形式，取第一个元素。
  static String _field(Map<dynamic, dynamic> fields, String name) {
    final value = fields[name];
    if (value is List) {
      return value.isNotEmpty ? value.first.toString() : '';
    }
    return value?.toString() ?? '';
  }

  static int _fieldInt(Map<dynamic, dynamic> fields, String name) =>
      int.tryParse(_field(fields, name)) ?? 0;

  Repo _repoOf(dynamic hit) {
    final map = hit is Map ? hit : const <String, dynamic>{};
    final fields = (map['fields'] is Map
            ? map['fields']
            : const <String, dynamic>{})
        as Map<dynamic, dynamic>;
    final fullName = _field(fields, 'title');
    final slash = fullName.indexOf('/');
    final langs = fields['langs'];
    final language = langs is List && langs.isNotEmpty ? langs.first : '';
    return Repo(
      id: int.tryParse(map['_id']?.toString() ?? '') ?? 0,
      fullName: fullName,
      name: slash > 0 ? fullName.substring(slash + 1) : fullName,
      description: () {
        final desc = _field(fields, 'description');
        return desc.isEmpty ? '暂无描述' : desc;
      }(),
      ownerLogin: _field(fields, 'owner.path.keyword'),
      ownerAvatar: '',
      stars: _fieldInt(fields, 'count.star'),
      forks: _fieldInt(fields, 'count.fork'),
      watchers: 0,
      language: language.toString(),
      isPrivate: false,
      htmlUrl: _field(fields, 'url'),
      updatedAt: _field(fields, 'last_push_at'),
    );
  }
}
