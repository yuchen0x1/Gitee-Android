import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OfflineCacheEntry {
  final dynamic value;
  final DateTime savedAt;

  const OfflineCacheEntry({required this.value, required this.savedAt});
}

/// 持久化最近阅读内容；缓存键按账号作用域隔离，不保存原始令牌。
class OfflineCache {
  OfflineCache._();

  static const _prefix = 'offline_cache_v2_';
  static const _maxEntryBytes = 512 * 1024;
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static String key({
    required String? token,
    required String type,
    required List<String> parts,
  }) {
    final scope = _scope(token);
    final encodedParts = parts.map(_encode).join('_');
    return '$_prefix$scope|$type|$encodedParts';
  }

  static Future<void> write({
    required String key,
    required dynamic value,
  }) async {
    try {
      final payload = jsonEncode({
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'value': value,
      });
      if (utf8.encode(payload).length > _maxEntryBytes) return;
      await _storage.write(key: key, value: payload);
    } catch (_) {}
  }

  static Future<OfflineCacheEntry?> read(String key) async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final savedAt = DateTime.tryParse(decoded['savedAt']?.toString() ?? '');
      if (savedAt == null || !decoded.containsKey('value')) return null;
      return OfflineCacheEntry(
          value: decoded['value'], savedAt: savedAt.toLocal());
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final all = await _storage.readAll();
      for (final key in all.keys.where((key) =>
          key.startsWith(_prefix) || key.startsWith('offline_cache_v1_'))) {
        await _storage.delete(key: key);
      }
    } catch (_) {}
  }

  static String _scope(String? token) {
    if (token == null || token.isEmpty) return 'anonymous';
    return sha256.convert(utf8.encode(token)).toString();
  }

  static String _encode(String value) =>
      base64UrlEncode(utf8.encode(value)).replaceAll('=', '');
}
