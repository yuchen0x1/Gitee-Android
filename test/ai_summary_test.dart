import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitee_client/ai/ai_summary.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    AiSummary.apiKey = 'test-key';
    AiSummary.baseUrl = 'https://example.com';
  });
  tearDown(() {
    AiSummary.apiKey = null;
    AiSummary.baseUrl = 'https://api.deepseek.com';
  });

  for (final base in [
    'https://example.com',
    'https://example.com/',
    'https://example.com/v1',
    'https://example.com/v1/',
  ]) {
    test('normalizes AI endpoint $base', () async {
      AiSummary.baseUrl = base;
      final result = await http.runWithClient(
        () => AiSummary.summarize('content'),
        () => MockClient((request) async {
          expect(request.url.toString(),
              'https://example.com/v1/chat/completions');
          return http.Response(
              '{"choices":[{"message":{"content":" summary "}}]}', 200);
        }),
      );
      expect(result, 'summary');
    });
  }

  test('network and timeout failures return a recoverable message', () async {
    for (final error in [http.ClientException('offline'), TimeoutException('')]) {
      final result = await http.runWithClient(
        () => AiSummary.summarize('content'),
        () => MockClient((_) async => throw error),
      );
      expect(result, startsWith('AI 请求'));
    }
  });

  test('invalid JSON and unexpected AI response shapes are handled', () async {
    for (final body in [
      'invalid JSON',
      '[]',
      '{"choices":[null]}',
      '{"choices":[{"message":[]}]}',
      '{"choices":[{"message":{"content":[]}}]}',
      '{"choices":[{"message":{"content":"  "}}]}',
    ]) {
      final result = await http.runWithClient(
        () => AiSummary.summarize('content'),
        () => MockClient((_) async => http.Response(body, 200)),
      );
      expect(result, '无法解析 AI 响应');
    }
  });

  test('invalid AI base URL is rejected before sending a request', () async {
    AiSummary.baseUrl = 'javascript:alert(1)';
    final result = await http.runWithClient(
      () => AiSummary.summarize('content'),
      () => MockClient((_) async => fail('Unexpected network request')),
    );
    expect(result, contains('接口地址无效'));
  });
}
