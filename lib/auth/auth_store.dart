import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the Gitee token outside of ordinary app preferences.
class AuthStore {
  AuthStore._();

  static const _tokenKey = 'gitee_token';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static Future<void> _pendingTokenOperation = Future<void>.value();

  static Future<T> _withToken<T>(Future<T> Function() operation) {
    final next = _pendingTokenOperation.then<T>((_) => operation());
    // A failed operation must not block later login or logout attempts.
    _pendingTokenOperation = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  static Future<String?> readToken() => _withToken(() async {
        final secureToken = await _secureStorage.read(key: _tokenKey);
        final prefs = await SharedPreferences.getInstance();
        if (secureToken != null && secureToken.isNotEmpty) {
          // A previous migration may have saved securely before cleanup finished.
          await prefs.remove(_tokenKey);
          return secureToken;
        }

        final legacyToken = prefs.getString(_tokenKey);
        if (legacyToken == null || legacyToken.isEmpty) return null;
        await _secureStorage.write(key: _tokenKey, value: legacyToken);
        await prefs.remove(_tokenKey);
        return legacyToken;
      });

  static Future<void> writeToken(String token) =>
      _withToken(() => _secureStorage.write(key: _tokenKey, value: token));

  static Future<void> clear() => _withToken(() async {
        await _secureStorage.delete(key: _tokenKey);
        // 旧版本遗留的 OAuth 键，登出时一并清理。
        await _secureStorage.delete(key: 'gitee_oauth_token');
        await _secureStorage.delete(key: 'gitee_oauth_state');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
      });

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
  }) async {
    final accounts = await readAccounts();
    accounts.removeWhere((a) => a['username'] == username);
    accounts.insert(0, {
      'username': username,
      'token': token,
      'avatarUrl': avatarUrl,
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
  static Future<bool> switchAccount(String username) async {
    final accounts = await readAccounts();
    final target = accounts.firstWhere(
      (a) => a['username'] == username,
      orElse: () => {},
    );
    final token = target['token'];
    if (token == null || token.isEmpty) return false;

    await writeToken(token);
    return true;
  }
}
