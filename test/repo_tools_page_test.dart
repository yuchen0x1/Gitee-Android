import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gitee_client/api/api_client.dart';
import 'package:gitee_client/api/gitee_api.dart';
import 'package:gitee_client/pages/repo_tools_page.dart';

http.Response resource(String path) {
  if (path.endsWith('/branches')) {
    return http.Response('[{"name":"main","commit":{"sha":"abc123"}}]', 200);
  }
  if (path.endsWith('/languages')) {
    return http.Response(
        '{"languages":[{"language":"Dart","percent":100}]}', 200);
  }
  if (path.endsWith('/license') || path.endsWith('/traffic-data')) {
    return http.Response('{}', 200);
  }
  return http.Response('[]', 200);
}

void main() {
  tearDown(() => GiteeApi.setClientForTest(ApiClient()));

  testWidgets(
      'forbidden management resources and missing license preserve public sections',
      (tester) async {
    final calls = <String, int>{};
    GiteeApi.setClientForTest(ApiClient(client: MockClient((request) async {
      final path = request.url.path;
      calls.update(path, (value) => value + 1, ifAbsent: () => 1);
      if (path.endsWith('/hooks') || path.endsWith('/collaborators')) {
        return http.Response('{}', 403);
      }
      if (path.endsWith('/license')) return http.Response('{}', 404);
      return resource(path);
    })));
    await tester.pumpWidget(
        const MaterialApp(home: RepoToolsPage(owner: 'o', repo: 'r')));
    await tester.pumpAndSettle();
    expect(find.text('main'), findsOneWidget);
    expect(find.text('Dart'), findsOneWidget);
    expect(calls.values.every((count) => count == 1), isTrue);
    await tester.scrollUntilVisible(find.textContaining('Webhook加载失败'), 400);
    expect(find.textContaining('Webhook加载失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful refresh clears previous extra-section errors',
      (tester) async {
    var fail = true;
    GiteeApi.setClientForTest(ApiClient(client: MockClient((request) async {
      if (request.url.path.endsWith('/labels')) {
        if (fail) return http.Response('{}', 500);
        return http.Response(
            jsonEncode([
              {'id': 1, 'name': 'bug', 'color': 'FF0000'}
            ]),
            200);
      }
      return resource(request.url.path);
    })));
    await tester.pumpWidget(
        const MaterialApp(home: RepoToolsPage(owner: 'o', repo: 'r')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('加载失败：'), 300);
    expect(find.textContaining('加载失败：'), findsOneWidget);
    fail = false;
    await tester.tap(find.byTooltip('刷新仓库信息'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('bug'), 300);
    expect(find.text('bug'), findsOneWidget);
    expect(find.textContaining('加载失败：'), findsNothing);
  });

  testWidgets(
      'a slow extra does not block the core repository surface or other extras',
      (tester) async {
    final traffic = Completer<http.Response>();
    GiteeApi.setClientForTest(ApiClient(client: MockClient((request) async {
      if (request.url.path.endsWith('/traffic-data')) return traffic.future;
      return resource(request.url.path);
    })));
    await tester.pumpWidget(
        const MaterialApp(home: RepoToolsPage(owner: 'o', repo: 'r')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('main'), findsOneWidget);
    expect(find.text('Dart'), findsOneWidget);
    traffic.complete(http.Response('{}', 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
