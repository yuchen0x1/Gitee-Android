import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitee_client/auth/auth_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('legacy token migrates to secure storage and plaintext is removed',
      () async {
    SharedPreferences.setMockInitialValues({'gitee_token': 'legacy'});

    expect(await AuthStore.readToken(), 'legacy');
    expect(await const FlutterSecureStorage().read(key: 'gitee_token'), 'legacy');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('gitee_token'), isFalse);
  });

  test('existing secure token wins and stale plaintext is still removed',
      () async {
    FlutterSecureStorage.setMockInitialValues({'gitee_token': 'current'});
    SharedPreferences.setMockInitialValues({'gitee_token': 'obsolete'});

    expect(await AuthStore.readToken(), 'current');
    expect(await const FlutterSecureStorage().read(key: 'gitee_token'), 'current');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('gitee_token'), isFalse);
  });

  test('logout removes current and legacy credentials but retains saved accounts',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'gitee_token': 'current',
      'gitee_oauth_token': 'legacy',
      'gitee_oauth_state': 'state',
      'gitee_accounts': '[]',
    });
    SharedPreferences.setMockInitialValues({'gitee_token': 'obsolete'});

    await AuthStore.clear();

    final values = await const FlutterSecureStorage().readAll();
    expect(values, {'gitee_accounts': '[]'});
    expect(await AuthStore.readToken(), isNull);
  });

  test('new login queued during logout retains its token', () async {
    FlutterSecureStorage.setMockInitialValues({'gitee_token': 'old'});

    final logout = AuthStore.clear();
    final login = AuthStore.writeToken('new');
    await Future.wait([logout, login]);

    expect(await AuthStore.readToken(), 'new');
  });
}
