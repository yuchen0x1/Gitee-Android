import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'oauth_token.dart';

/// Stores the Gitee token outside of ordinary app preferences.
class AuthStore {
  AuthStore._();

  static const _tokenKey = 'gitee_token';
  static const _oauthKey = 'gitee_oauth_token';
  static const _oauthStateKey = 'gitee_oauth_state';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<String?> readToken() async {
    final secureToken = await _secureStorage.read(key: _tokenKey);
    if (secureToken != null && secureToken.isNotEmpty) return secureToken;

    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_tokenKey);
    if (legacyToken == null || legacyToken.isEmpty) return null;
    await writeToken(legacyToken);
    await prefs.remove(_tokenKey);
    return legacyToken;
  }

  static Future<void> writeToken(String token) =>
      _secureStorage.write(key: _tokenKey, value: token);

  static Future<void> writeOAuthToken(OAuthToken token) async {
    await writeToken(token.accessToken);
    await _secureStorage.write(
      key: _oauthKey,
      value: jsonEncode(token.toStoredJson()),
    );
  }

  static Future<OAuthToken?> readOAuthToken() async {
    final raw = await _secureStorage.read(key: _oauthKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return OAuthToken.fromStoredJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      await _secureStorage.delete(key: _oauthKey);
      return null;
    }
  }

  static Future<void> clearOAuthToken() =>
      _secureStorage.delete(key: _oauthKey);

  static Future<void> writeOAuthState(String state) =>
      _secureStorage.write(key: _oauthStateKey, value: state);

  static Future<String?> readOAuthState() =>
      _secureStorage.read(key: _oauthStateKey);

  static Future<void> clearOAuthState() =>
      _secureStorage.delete(key: _oauthStateKey);

  static Future<void> updateOAuthAccount(
    OAuthToken previous,
    OAuthToken current,
  ) async {
    final accounts = await readAccounts();
    var changed = false;
    for (final account in accounts) {
      final raw = account['oauthToken'];
      if (raw == null || raw.isEmpty) continue;
      try {
        final stored = OAuthToken.fromStoredJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
        if (stored.accessToken != previous.accessToken) continue;
        account['token'] = current.accessToken;
        account['oauthToken'] = jsonEncode(current.toStoredJson());
        changed = true;
      } catch (_) {}
    }
    if (changed) {
      await _secureStorage.write(
        key: _accountsKey,
        value: jsonEncode(accounts),
      );
    }
  }

  static Future<void> clear() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _oauthKey);
    await _secureStorage.delete(key: _oauthStateKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ---------- 多账号管理 ----------

  static const _accountsKey = 'gitee_accounts';

  /// 已保存的所有账号。
  static Future<List<Map<String, String>>> readAccounts() async {
    final raw = await _secureStorage.read(key: _accountsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map((e) => e.map((k, v) => MapEntry(k, v.toString())))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 添加或更新账号信息。
  static Future<void> addAccount({
    required String username,
    required String token,
    String avatarUrl = '',
    OAuthToken? oauthToken,
  }) async {
    final accounts = await readAccounts();
    accounts.removeWhere((a) => a['username'] == username);
    accounts.insert(0, {
      'username': username,
      'token': token,
      'avatarUrl': avatarUrl,
      if (oauthToken != null)
        'oauthToken': jsonEncode(oauthToken.toStoredJson()),
    });
    await _secureStorage.write(key: _accountsKey, value: jsonEncode(accounts));
  }

  /// 移除账号。
  static Future<void> removeAccount(String username) async {
    final accounts = await readAccounts();
    accounts.removeWhere((a) => a['username'] == username);
    await _secureStorage.write(key: _accountsKey, value: jsonEncode(accounts));
  }

  /// 切换到指定账号并更新当前令牌。
  static Future<bool> switchAccount(
    String username, {
    Future<OAuthToken> Function(OAuthToken)? refreshOAuthToken,
  }) async {
    final accounts = await readAccounts();
    final target = accounts.firstWhere(
      (a) => a['username'] == username,
      orElse: () => {},
    );
    final token = target['token'];
    if (token == null || token.isEmpty) return false;

    OAuthToken? oauthToken;
    final rawOAuthToken = target['oauthToken'];
    if (rawOAuthToken != null && rawOAuthToken.isNotEmpty) {
      try {
        oauthToken = OAuthToken.fromStoredJson(
          Map<String, dynamic>.from(jsonDecode(rawOAuthToken) as Map),
        );
        if (oauthToken.isExpired && refreshOAuthToken != null) {
          oauthToken = await refreshOAuthToken(oauthToken);
          target['token'] = oauthToken.accessToken;
          target['oauthToken'] = jsonEncode(oauthToken.toStoredJson());
          await _secureStorage.write(
            key: _accountsKey,
            value: jsonEncode(accounts),
          );
        }
      } catch (_) {
        return false;
      }
    }

    await writeToken(oauthToken?.accessToken ?? target['token']!);
    if (oauthToken == null) {
      await clearOAuthToken();
    } else {
      await writeOAuthToken(oauthToken);
    }
    return true;
  }
}
