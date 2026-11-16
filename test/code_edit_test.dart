import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gitee_client/api/api_client.dart';
import 'package:gitee_client/api/gitee_api.dart';
import 'package:gitee_client/pages/code_view_page.dart';

void main() {
  testWidgets('editing sends plain text once encoded to the selected branch',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    http.Request? write;
    GiteeApi.setClientForTest(ApiClient(
        token: 'a',
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            write = request;
            return http.Response('{}', 200);
          }
          expect(request.url.queryParameters['ref'], 'master');
          return http.Response(
              jsonEncode({
                'content': base64Encode(utf8.encode('old')),
                'sha': 'sha-1'
              }),
              200);
        })));
    await tester.pumpWidget(const MaterialApp(
        home: CodeViewPage(
            owner: 'o',
            repo: 'r',
            path: 'main.dart',
            fileName: 'main.dart',
            branch: 'master')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑文件'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新的内容\nhello');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final body = Uri.splitQueryString(utf8.decode(write!.bodyBytes));
    expect(utf8.decode(base64Decode(body['content']!)), '新的内容\nhello');
    expect(body['branch'], 'master');
    expect(body['sha'], 'sha-1');
    expect(tester.takeException(), isNull);
  });
}
