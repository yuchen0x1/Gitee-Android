import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitee_client/ai/ai_summary.dart';
import 'package:gitee_client/pages/ai_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AiSummary.apiKey = null);

  test('secure AI key takes precedence and stale plaintext key is removed',
      () async {
    SharedPreferences.setMockInitialValues({'ai_api_key': 'legacy-key'});
    FlutterSecureStorage.setMockInitialValues(
        {'ai_api_key_secure': 'secure-key'});
    await AiSettingsPage.loadFromPrefs();
    expect(AiSummary.apiKey, 'secure-key');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('ai_api_key'), isFalse);
  });

  test('legacy AI key migrates before its plaintext copy is removed', () async {
    SharedPreferences.setMockInitialValues({'ai_api_key': 'legacy-key'});
    FlutterSecureStorage.setMockInitialValues({});
    await AiSettingsPage.loadFromPrefs();
    expect(AiSummary.apiKey, 'legacy-key');
    expect(await const FlutterSecureStorage().read(key: 'ai_api_key_secure'),
        'legacy-key');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('ai_api_key'), isFalse);
  });
}
