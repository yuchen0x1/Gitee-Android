import 'dart:convert';
import 'package:http/http.dart' as http;

/// AI 摘要服务：调用大模型对 Issue/PR 做中文一句话摘要。
/// 默认使用 DeepSeek API（兼容 OpenAI 格式），可通过 [baseUrl] 切换到
/// 通义千问、GLM-4 等任何兼容 OpenAI Chat 格式的接口。
class AiSummary {
  AiSummary._();

  /// 设置 API 密钥和可选的 base URL。
  static String? apiKey;
  static String baseUrl = 'https://api.deepseek.com';
  static String model = 'deepseek-chat';

  static bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  /// 对一段文本生成简短中文摘要。
  static Future<String> summarize(String content, {String? title}) async {
    if (!isConfigured) return '请先在设置中配置 AI API Key';
    final userMsg = title != null && title.isNotEmpty
        ? '标题：$title\n\n内容：$content'
        : content;
    final body = jsonEncode({
      'model': model,
      'messages': [
        {
          'role': 'system',
          'content': '你是代码仓库助手。请用 3 句话以内的中文总结以下 Issue 或 Pull Request 的核心内容、'
              '关键讨论和当前状态。不要输出标题或格式，直接给出摘要文本。',
        },
        {'role': 'user', 'content': userMsg},
      ],
      'max_tokens': 300,
      'temperature': 0.3,
    });
    final res = await http
        .post(
          Uri.parse('$baseUrl/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      return 'AI 请求失败（${res.statusCode}）';
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      return choices[0]['message']?['content']?.toString().trim() ?? '无法生成摘要';
    }
    return '无法解析 AI 响应';
  }
}
