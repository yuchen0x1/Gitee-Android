import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitee_client/auth/auth_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('delayed logout deletion finishes before a new token is written',
      () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final values = <String, String>{'gitee_token': 'old'};
    messenger.setMockMethodCallHandler(channel, (call) async {
      final arguments = call.arguments as Map;
      final key = arguments['key'] as String;
      switch (call.method) {
        case 'delete':
          if (key == 'gitee_token') {
            started.complete();
            await release.future;
          }
          values.remove(key);
          return null;
        case 'write':
          values[key] = arguments['value'] as String;
          return null;
        case 'read':
          return values[key];
        default:
          throw StateError('Unexpected storage method: ${call.method}');
      }
    });

    final logout = AuthStore.clear();
    await started.future;
    var loginFinished = false;
    final login = AuthStore.writeToken('new').then((_) => loginFinished = true);
    try {
      await Future<void>.delayed(Duration.zero);
      expect(loginFinished, isFalse);
    } finally {
      release.complete();
      await logout;
      await login;
    }

    expect(await AuthStore.readToken(), 'new');
  });

  test('a failed deletion does not block a later login', () async {
    final values = <String, String>{};
    messenger.setMockMethodCallHandler(channel, (call) async {
      final arguments = call.arguments as Map;
      final key = arguments['key'] as String;
      if (call.method == 'delete') {
        throw PlatformException(code: 'storage-unavailable');
      }
      if (call.method == 'write') {
        values[key] = arguments['value'] as String;
      } else if (call.method == 'read') {
        return values[key];
      }
      return null;
    });

    await expectLater(AuthStore.clear(), throwsA(isA<PlatformException>()));
    await AuthStore.writeToken('new');
    expect(await AuthStore.readToken(), 'new');
  });
}
