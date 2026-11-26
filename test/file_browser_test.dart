import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitee_client/api/api_client.dart';
import 'package:gitee_client/api/gitee_api.dart';
import 'package:gitee_client/pages/repo_file_browser_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('breadcrumbs navigate to their directory and the repository root',
      (tester) async {
    final paths = <String>[];
    GiteeApi.setClientForTest(ApiClient(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/branches')) {
          return http.Response('[{"name":"main"}]', 200);
        }
        paths.add(request.url.path);
        return http.Response(
            jsonEncode([
              {'name': 'file.txt', 'path': 'file.txt', 'type': 'file'}
            ]),
            200);
      }),
    ));
    await tester.pumpWidget(const MaterialApp(
      home: RepoFileBrowserPage(
        owner: 'o',
        repo: 'r',
        initialPath: 'src/nested',
        initialBranch: 'main',
      ),
    ));
    await tester.pumpAndSettle();
    expect(paths.last, endsWith('/contents/src/nested'));
    await tester.tap(find.text('src'));
    await tester.pumpAndSettle();
    expect(paths.last, endsWith('/contents/src'));
    await tester.tap(find.text('/'));
    await tester.pumpAndSettle();
    expect(paths.last, endsWith('/contents'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
