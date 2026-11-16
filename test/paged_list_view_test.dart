import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitee_client/widgets/paged_list_view.dart';

Widget app(GlobalKey<PagedListViewState<String>> key,
        Future<List<String>> Function(int) load) =>
    MaterialApp(
        home: Scaffold(
            body: PagedListView<String>(
                key: key,
                loadPage: load,
                pageSize: 2,
                emptyTitle: 'empty',
                itemBuilder: (_, item) => Text(item))));

void main() {
  testWidgets('page failure keeps items and retries the same page',
      (tester) async {
    final key = GlobalKey<PagedListViewState<String>>();
    final pages = <int>[];
    var fail = true;
    await tester.pumpWidget(app(key, (page) async {
      pages.add(page);
      if (page == 1) return ['one', 'two'];
      if (fail) throw Exception('offline');
      return ['three'];
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载更多'));
    await tester.pumpAndSettle();
    expect(find.text('one'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(pages, [1, 2, 2]);
    expect(find.text('three'), findsOneWidget);
    expect(find.text('没有更多了'), findsOneWidget);
  });

  testWidgets('failed refresh keeps data and retries page one', (tester) async {
    final key = GlobalKey<PagedListViewState<String>>();
    var calls = 0;
    await tester.pumpWidget(app(key, (page) async {
      expect(page, 1);
      calls++;
      if (calls == 2) throw Exception('offline');
      return [calls == 1 ? 'old' : 'fresh'];
    }));
    await tester.pumpAndSettle();
    await key.currentState!.refresh();
    await tester.pumpAndSettle();
    expect(find.text('old'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('fresh'), findsOneWidget);
    expect(find.text('old'), findsNothing);
  });

  testWidgets('refresh supersedes an in-flight append', (tester) async {
    final key = GlobalKey<PagedListViewState<String>>();
    final append = Completer<List<String>>();
    var firstPageCalls = 0;
    await tester.pumpWidget(app(key, (page) async {
      if (page == 2) return append.future;
      return ++firstPageCalls == 1 ? ['one', 'two'] : ['fresh'];
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载更多'));
    await tester.pump();
    await key.currentState!.refresh();
    await tester.pumpAndSettle();
    append.complete(['stale']);
    await tester.pumpAndSettle();
    expect(find.text('fresh'), findsOneWidget);
    expect(find.text('stale'), findsNothing);
  });
}
