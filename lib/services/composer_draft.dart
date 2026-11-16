import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Serializes persistence across sheets, including close followed by reopen.
class DraftStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static Future<void>? _pending;

  static String key(String? token, String kind, String owner, String repo) =>
      'composer_draft_v1_${sha256.convert(utf8.encode(jsonEncode([
            token,
            kind,
            owner,
            repo
          ])))}';

  static Future<Map<String, String>> read(String key) async {
    final pending = _pending;
    if (pending != null) await pending;
    final raw = await _storage.read(key: key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['fields'] is! Map) {
      throw const FormatException('Invalid draft');
    }
    return (decoded['fields'] as Map).map((key, value) {
      if (key is! String || value is! String) {
        throw const FormatException('Invalid draft field');
      }
      return MapEntry(key, value);
    });
  }

  static Future<void> write(String key, Map<String, String> fields) async {
    final hasContent = fields.values.any((value) => value.trim().isNotEmpty);
    final payload = jsonEncode({
      'fields': fields,
      'savedAt': DateTime.now().toUtc().toIso8601String()
    });
    final previous = _pending;
    final done = Completer<void>();
    _pending = done.future;
    try {
      if (previous != null) await previous;
      if (!hasContent) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: payload);
      }
    } finally {
      if (identical(_pending, done.future)) _pending = null;
      // The queue signal succeeds; the returned Future reports write errors.
      done.complete();
    }
  }
}

/// Owns autosave state; the caller continues to own its text controllers.
class ComposerDraft extends ChangeNotifier with WidgetsBindingObserver {
  ComposerDraft(
      {required String? token,
      required String kind,
      required String owner,
      required String repo,
      required this.fields})
      : key = DraftStore.key(token, kind, owner, repo) {
    WidgetsBinding.instance.addObserver(this);
    for (final controller in fields.values) {
      controller.addListener(_changed);
    }
  }

  final String key;
  final Map<String, TextEditingController> fields;
  Timer? _timer;
  bool loading = true;
  bool restored = false;
  bool saving = false;
  bool saved = false;
  String? error;
  bool _disposed = false;
  bool _applying = false;
  bool _completed = false;
  bool _dirty = false;
  int _revision = 0;

  bool get hasContent => fields.values.any((c) => c.text.trim().isNotEmpty);

  Future<void> restore() async {
    try {
      final values = await DraftStore.read(key);
      if (_disposed) return;
      _applying = true;
      for (final field in fields.entries) {
        field.value.text = values[field.key] ?? '';
      }
      restored = hasContent;
      saved = restored;
    } catch (_) {
      error = '草稿读取失败，输入仍可继续';
    } finally {
      _applying = false;
      loading = false;
      _notify();
    }
  }

  void _changed() {
    if (loading || _applying || _completed) return;
    _revision++;
    _dirty = true;
    saved = false;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), saveNow);
    _notify();
  }

  Future<void> saveNow() async {
    if (loading || _completed || !_dirty) return;
    _timer?.cancel();
    final revision = _revision;
    final values =
        fields.map((key, controller) => MapEntry(key, controller.text));
    saving = true;
    _notify();
    try {
      await DraftStore.write(key, values);
      if (revision == _revision) {
        saved = true;
        _dirty = false;
        error = null;
      }
    } catch (_) {
      error = '草稿保存失败，请保留当前页面并重试';
    } finally {
      saving = false;
      _notify();
    }
  }

  Future<void> clear() async {
    _applying = true;
    for (final controller in fields.values) {
      controller.clear();
    }
    _applying = false;
    restored = false;
    _revision++;
    _dirty = true;
    await saveNow();
  }

  Future<void> retry() => _dirty ? saveNow() : restore();

  /// Only clear a submitted draft after the server acknowledged creation.
  Future<void> complete() async {
    _completed = true;
    _timer?.cancel();
    try {
      await DraftStore.write(key, {});
    } catch (_) {
      // Do not misreport a successful server creation as a failed submission.
      error = '提交成功，但本地草稿未能清除';
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(saveNow());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _disposed = true;
    // Snapshot synchronously before the form disposes the controllers.
    unawaited(saveNow());
    for (final controller in fields.values) {
      controller.removeListener(_changed);
    }
    super.dispose();
  }
}
