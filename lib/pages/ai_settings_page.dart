import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ai/ai_summary.dart';

/// AI 设置页：配置 API Key、Base URL、Model。
class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const _aiKeySecretKey = 'ai_api_key_secure';

  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // 优先从安全存储读取，兼顾从旧版本 SharedPreferences 迁移
    var key = await _secureStorage.read(key: _aiKeySecretKey);
    if (key == null || key.isEmpty) {
      final legacyKey = prefs.getString('ai_api_key');
      if (legacyKey != null && legacyKey.isNotEmpty) {
        key = legacyKey;
        await _secureStorage.write(key: _aiKeySecretKey, value: legacyKey);
        await prefs.remove('ai_api_key');
      }
    }
    AiSummary.apiKey = (key != null && key.isNotEmpty) ? key : null;
    final url = prefs.getString('ai_base_url') ?? '';
    if (url.isNotEmpty) AiSummary.baseUrl = url;
    final model = prefs.getString('ai_model') ?? '';
    if (model.isNotEmpty) AiSummary.model = model;
  }

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  late TextEditingController _keyCtrl;
  late TextEditingController _urlCtrl;
  late TextEditingController _modelCtrl;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: AiSummary.apiKey ?? '');
    _urlCtrl = TextEditingController(text: AiSummary.baseUrl);
    _modelCtrl = TextEditingController(text: AiSummary.model);
  }

  Future<void> _save() async {
    AiSummary.apiKey =
        _keyCtrl.text.trim().isEmpty ? null : _keyCtrl.text.trim();
    AiSummary.baseUrl = _urlCtrl.text.trim().isEmpty
        ? 'https://api.deepseek.com'
        : _urlCtrl.text.trim();
    AiSummary.model = _modelCtrl.text.trim().isEmpty
        ? 'deepseek-chat'
        : _modelCtrl.text.trim();
    final prefs = await SharedPreferences.getInstance();
    if (AiSummary.apiKey != null && AiSummary.apiKey!.isNotEmpty) {
      await AiSettingsPage._secureStorage.write(
        key: AiSettingsPage._aiKeySecretKey,
        value: AiSummary.apiKey!,
      );
    } else {
      await AiSettingsPage._secureStorage.delete(key: AiSettingsPage._aiKeySecretKey);
    }
    await prefs.remove('ai_api_key');
    await prefs.setString('ai_base_url', AiSummary.baseUrl);
    await prefs.setString('ai_model', AiSummary.model);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('AI 设置已保存')));
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _urlCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _keyCtrl,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'sk-...',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'https://api.deepseek.com',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _modelCtrl,
            decoration: const InputDecoration(
              labelText: '模型名称',
              hintText: 'deepseek-chat',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '支持任何 OpenAI Chat 兼容接口：DeepSeek、通义千问、GLM-4 等',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
