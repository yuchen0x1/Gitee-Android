import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gitee_client/api/api_client.dart';
import 'package:gitee_client/api/gitee_api.dart';
import 'package:gitee_client/services/composer_draft.dart';
import 'package:gitee_client/widgets/issue_composer.dart';
import 'package:gitee_client/widgets/pr_composer.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final kind in ['issue', 'pr']) {
    testWidgets('$kind restores all fields and clears only after success',
        (tester) async {
      final fields = kind == 'issue'
          ? {'title': '草稿标题', 'body': '草稿正文', 'labels': 'bug'}
          : {
              'title': '草稿标题',
              'body': '草稿正文',
              'head': 'feature',
              'base': 'main'
            };
      final key = DraftStore.key('a', kind, 'owner', 'repo');
      await DraftStore.write(key, fields);
      var fail = true;
      http.Request? captured;
      GiteeApi.setClientForTest(ApiClient(
          token: 'a',
          client: MockClient((request) async {
            captured = request;
            return http.Response('{}', fail ? 500 : 201);
          })));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () {
                        if (kind == 'issue') {
                          showCreateIssueSheet(context,
                              owner: 'owner', repo: 'repo');
                        } else {
                          showCreatePullRequestSheet(context,
                              owner: 'owner', repo: 'repo');
                        }
                      },
                      child: const Text('open'))))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('已恢复本地草稿'), findsOneWidget);
      for (final value in fields.values) {
        expect(find.text(value), findsOneWidget);
      }
      final submit =
          find.widgetWithText(FilledButton, kind == 'issue' ? '创建' : '创建 PR');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(await DraftStore.read(key), fields);
      fail = false;
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(await DraftStore.read(key), isEmpty);
      expect(find.text('open'), findsOneWidget);
      expect(captured!.headers['Authorization'], 'token a');
      final body = Uri.splitQueryString(utf8.decode(captured!.bodyBytes));
      expect(body['title'], fields['title']);
      expect(body['body'], fields['body']);
      if (kind == 'pr') {
        expect(body['head'], 'feature');
        expect(body['base'], 'main');
      }
    });
  }

  testWidgets('PR sheet fits narrow screen with large text and keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    GiteeApi.setClientForTest(ApiClient(token: 'a'));
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
                viewInsets: const EdgeInsets.only(bottom: 220)),
            child: child!),
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showCreatePullRequestSheet(context,
                        owner: 'o', repo: 'r'),
                    child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
