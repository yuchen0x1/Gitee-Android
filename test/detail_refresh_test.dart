import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitee_client/ai/ai_summary.dart';
import 'package:gitee_client/api/api_client.dart';
import 'package:gitee_client/api/gitee_api.dart';
import 'package:gitee_client/pages/issue_detail_page.dart';
import 'package:gitee_client/pages/pr_detail_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final kind in ['issue', 'pr']) {
    testWidgets('$kind refresh ignores an older in-flight next page',
        (tester) async {
      final append = Completer<http.Response>();
      final pages = <int>[];
      var firstPageCalls = 0;
      GiteeApi.setClientForTest(ApiClient(
        token: 'a',
        client: MockClient((request) async {
          final path = request.url.path;
          final paged = kind == 'issue'
              ? path.endsWith('/issues/1/comments')
              : path.endsWith('/pulls/1/commits');
          if (paged) {
            final page = int.parse(request.url.queryParameters['page']!);
            pages.add(page);
            if (page == 2) return append.future;
            final initial = ++firstPageCalls == 1;
            return http.Response(
                jsonEncode(List.generate(initial ? 20 : 1, (index) {
                  final label = initial ? 'initial-$index' : 'fresh';
                  return kind == 'issue'
                      ? {'id': index + 1, 'body': label}
                      : {
                          'sha': label,
                          'commit': {'message': label}
                        };
                })),
                200);
          }
          if (path.endsWith('/issues/1') || path.endsWith('/pulls/1')) {
            return http.Response(
                '{"number":1,"title":"Details","state":"open"}', 200);
          }
          return http.Response('[]', 200);
        }),
      ));
      await tester.pumpWidget(MaterialApp(
        home: kind == 'issue'
            ? const IssueDetailPage(owner: 'o', repo: 'r', number: '1')
            : const PullRequestDetailPage(owner: 'o', repo: 'r', number: 1),
      ));
      await tester.pumpAndSettle();
      final listFinder = find
          .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byWidgetPredicate(
                (widget) => widget is ListView && widget.controller != null),
          )
          .first;
      final controller = tester.widget<ListView>(listFinder).controller!;
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(pages, [1, 2]);

      final refresh = tester.widget<RefreshIndicator>(
          find.byType(RefreshIndicator));
      await refresh.onRefresh();
      await tester.pumpAndSettle();
      append.complete(http.Response(
          kind == 'issue'
              ? '[{"id":99,"body":"stale"}]'
              : '[{"sha":"stale","commit":{"message":"stale"}}]',
          200));
      await tester.pumpAndSettle();

      final list = tester.widget<ListView>(listFinder);
      final delegate = list.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.childCount, kind == 'issue' ? 4 : 7);
      expect(pages, [1, 2, 1]);
      expect(find.text('stale'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('$kind delete failure after leaving the detail page is ignored',
        (tester) async {
      final deletion = Completer<http.Response>();
      var deleteStarted = false;
      GiteeApi.setClientForTest(ApiClient(
        token: 'a',
        client: MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'DELETE') {
            expect(path,
                endsWith('/${kind == 'issue' ? 'issues' : 'pulls'}/comments/7'));
            deleteStarted = true;
            return deletion.future;
          }
          if (path.endsWith('/issues/1') || path.endsWith('/pulls/1')) {
            return http.Response(
                '{"number":1,"title":"Details","state":"open"}', 200);
          }
          if (path.endsWith('/issues/1/comments') ||
              path.endsWith('/pulls/1/comments')) {
            return http.Response('[{"id":7,"body":"comment to delete"}]', 200);
          }
          return http.Response('[]', 200);
        }),
      ));
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: Builder(builder: (context) {
            return TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => kind == 'issue'
                    ? const IssueDetailPage(owner: 'o', repo: 'r', number: '1')
                    : const PullRequestDetailPage(
                        owner: 'o', repo: 'r', number: 1),
              )),
              child: const Text('open'),
            );
          }),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final commentMenu = find.descendant(
        of: find.byType(RefreshIndicator),
        matching: find.byType(PopupMenuButton<String>),
      );
      expect(commentMenu, findsOneWidget);
      await tester.ensureVisible(commentMenu);
      await tester.tap(commentMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除评论'));
      await tester.pumpAndSettle();
      expect(deleteStarted, isTrue);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      deletion.complete(http.Response('{"message":"server error"}', 500));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('open'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('AI completion after dismissing its spinner keeps the issue open',
      (tester) async {
    AiSummary.apiKey = 'test-key';
    addTearDown(() => AiSummary.apiKey = null);
    final response = Completer<http.Response>();
    GiteeApi.setClientForTest(ApiClient(client: MockClient((request) async {
      return http.Response(
          request.url.path.endsWith('/issues/1')
              ? '{"number":1,"title":"Details","state":"open","body":"Issue description"}'
              : '[]',
          200);
    })));
    final navigator = GlobalKey<NavigatorState>();
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: Builder(builder: (context) {
            return TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const IssueDetailPage(
                    owner: 'o', repo: 'r', number: '1'),
              )),
              child: const Text('open'),
            );
          }),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.smart_toy_outlined));
      await tester.pump();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      response.complete(http.Response(
          '{"choices":[{"message":{"content":"summary"}}]}', 200));
      await tester.pumpAndSettle();
      expect(find.byType(IssueDetailPage), findsOneWidget);
      expect(find.text('open'), findsNothing);
      expect(find.text('summary'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }, () => MockClient((request) {
      expect(request.body, contains('Issue description'));
      return response.future;
    }));
  });
}
