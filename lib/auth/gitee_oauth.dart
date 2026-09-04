import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'auth_store.dart';
import 'oauth_token.dart';

/// Gitee OAuth configuration injected at build time.
class GiteeOAuthConfig {
  static const clientId = String.fromEnvironment('GITEE_CLIENT_ID');
  static const clientSecret = String.fromEnvironment('GITEE_CLIENT_SECRET');
  static const redirectUri = String.fromEnvironment(
    'GITEE_REDIRECT_URI',
    defaultValue: 'gitee://oauth/callback',
  );

  static bool get isConfigured =>
      clientId.isNotEmpty && clientSecret.isNotEmpty && redirectUri.isNotEmpty;
}

class GiteeOAuthException implements Exception {
  const GiteeOAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Handles the browser-based Gitee OAuth authorization-code flow.
class GiteeOAuthService {
  GiteeOAuthService({
    http.Client? client,
    Future<bool> Function(Uri)? openUrl,
    String? clientId,
    String? clientSecret,
    String? redirectUri,
    Future<void> Function(String)? writeState,
    Future<String?> Function()? readState,
    Future<void> Function()? clearState,
  })  : _client = client ?? http.Client(),
        _openUrl = openUrl ??
            ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)),
        _clientId = clientId ?? GiteeOAuthConfig.clientId,
        _clientSecret = clientSecret ?? GiteeOAuthConfig.clientSecret,
        _redirectUri = redirectUri ?? GiteeOAuthConfig.redirectUri,
        _writeState = writeState ?? AuthStore.writeOAuthState,
        _readState = readState ?? AuthStore.readOAuthState,
        _clearState = clearState ?? AuthStore.clearOAuthState;

  static const authorizeEndpoint = 'https://gitee.com/oauth/authorize';
  static const tokenEndpoint = 'https://gitee.com/oauth/token';
  static const _timeout = Duration(seconds: 20);

  final http.Client _client;
  final Future<bool> Function(Uri) _openUrl;
  final String _clientId;
  final String _clientSecret;
  final String _redirectUri;
  final Future<void> Function(String) _writeState;
  final Future<String?> Function() _readState;
  final Future<void> Function() _clearState;
  final Random _random = Random.secure();
  String? _pendingState;

  bool get isConfigured =>
      _clientId.isNotEmpty &&
      _clientSecret.isNotEmpty &&
      _redirectUri.isNotEmpty;

  Future<String> _createState() async {
    final state = _newState();
    await _writeState(state);
    return state;
  }

  Future<Uri> createAuthorizationUri() async {
    _ensureConfigured();
    if (_pendingState != null) {
      throw const GiteeOAuthException('已有 Gitee 登录正在进行，请先完成或取消');
    }
    final state = await _createState();
    _pendingState = state;
    return Uri.parse(authorizeEndpoint).replace(queryParameters: {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'state': state,
    });
  }

  Future<void> beginAuthorization() async {
    final uri = await createAuthorizationUri();
    if (!await _openUrl(uri)) {
      await cancelAuthorization();
      throw const GiteeOAuthException('无法打开 Gitee 登录页面');
    }
  }

  Future<void> cancelAuthorization() async {
    _pendingState = null;
    await _clearState();
  }

  Future<OAuthToken> completeAuthorization(Uri callback) async {
    final configuredRedirect = Uri.parse(_redirectUri);
    if (callback.scheme != configuredRedirect.scheme ||
        callback.host != configuredRedirect.host ||
        callback.path != configuredRedirect.path) {
      throw const GiteeOAuthException('登录回调地址不匹配，请重新登录');
    }

    final state = callback.queryParameters['state'];
    final expectedState = _pendingState ?? await _readState();
    if (state == null || state.isEmpty || state != expectedState) {
      _pendingState = null;
      await _clearState();
      throw const GiteeOAuthException('登录回调校验失败，请重新登录');
    }
    _pendingState = null;
    await _clearState();

    final error = callback.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      final description = callback.queryParameters['error_description'];
      throw GiteeOAuthException(
        description == null || description.isEmpty
            ? 'Gitee 登录已取消或被拒绝'
            : 'Gitee 登录失败：$description',
      );
    }

    final code = callback.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const GiteeOAuthException('Gitee 回调缺少授权码');
    }
    return _exchangeCode(code);
  }

  Future<OAuthToken> refresh(OAuthToken token) async {
    final refreshToken = token.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const GiteeOAuthException('没有可用的刷新令牌');
    }
    _ensureConfigured();
    final response = await _postToken({
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    });
    final refreshed = OAuthToken.fromJson(response);
    return OAuthToken(
      accessToken: refreshed.accessToken,
      refreshToken: refreshed.refreshToken ?? refreshToken,
      expiresAt: refreshed.expiresAt ?? token.expiresAt,
      tokenType: refreshed.tokenType,
    );
  }

  Future<OAuthToken> _exchangeCode(String code) async {
    _ensureConfigured();
    final response = await _postToken({
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': _redirectUri,
    });
    return OAuthToken.fromJson(response);
  }

  Future<Map<String, dynamic>> _postToken(Map<String, String> body) async {
    late final http.Response response;
    try {
      response = await _client.post(
        Uri.parse(tokenEndpoint),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          ...body,
          'client_id': _clientId,
          'client_secret': _clientSecret,
        },
      ).timeout(_timeout);
    } on TimeoutException {
      throw const GiteeOAuthException('Gitee 登录请求超时，请稍后重试');
    } catch (_) {
      throw const GiteeOAuthException('无法连接 Gitee 登录服务，请检查网络连接');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? decoded['error_description'] ?? decoded['error']
          : null;
      throw GiteeOAuthException(
        message == null
            ? 'Gitee 登录失败（${response.statusCode}）'
            : 'Gitee 登录失败：$message',
      );
    }
    if (decoded is! Map) {
      throw const GiteeOAuthException('Gitee 登录响应格式错误');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const GiteeOAuthException(
        '未配置 Gitee OAuth 应用，请使用私人令牌登录或补充构建参数',
      );
    }
  }

  String _newState() {
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

final giteeOAuthService = GiteeOAuthService();
