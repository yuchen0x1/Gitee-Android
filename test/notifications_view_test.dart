import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gitee_client/api/api_client.dart';
import 'package:gitee_client/api/gitee_api.dart';
import 'package:gitee_client/widgets/notifications_view.dart';

Map<String, dynamic> notification(int id, {bool unread = true}) => {
      'id': id,
      'unread': unread,
      'repository': {'full_name': 'owner/repo'},
      'subject': {'title': 'Notification $id', 'type': 'IssueEvent'},
    };

Future<void> showInbox(
    WidgetTester tester, Future<http.Response> Function(http.Request) handler,
    {ValueChanged<int>? onCount, ThemeMode mode = ThemeMode.light}) async {
  GiteeApi.setClientForTest(
      ApiClient(token: 'fixture', client: MockClient(handler)));
  await tester.pumpWidget(MaterialApp(
      themeMode: mode,
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: NotificationsView(onUnreadCountChanged: onCount))));
  await tester.pumpAndSettle();
}

http.Response listResponse(List<Map<String, dynamic>> items) =>
    http.Response(jsonEncode({'list': items}), 200);

void main() {
  tearDown(() => GiteeApi.setClientForTest(ApiClient()));

  testWidgets('empty unread inbox keeps filter and refresh available',
      (tester) async {
    final filters = <String?>[];
    await showInbox(tester, (request) async {
      if (request.url.path.endsWith('/count')) {
        return http.Response('{"notification_count":0}', 200);
      }
      filters.add(request.url.queryParameters['unread']);
      return listResponse(request.url.queryParameters['unread'] == 'false'
          ? [notification(1, unread: false)]
          : []);
    });
    expect(find.text('未读通知已处理完'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '全部'));
    await tester.pumpAndSettle();
    expect(find.text('Notification 1'), findsOneWidget);
    expect(filters, ['true', 'false']);
    await tester.tap(find.byTooltip('刷新通知'));
    await tester.pumpAndSettle();
    expect(filters.length, 3);
  });

  testWidgets('failed single write keeps row and unread count and can retry',
      (tester) async {
    var fail = true;
    var read = false;
    var writes = 0;
    final counts = <int>[];
    await showInbox(tester, (request) async {
      if (request.method == 'PATCH') {
        writes++;
        if (fail) return http.Response('{}', 500);
        read = true;
        return http.Response('', 205);
      }
      if (request.url.path.endsWith('/count')) {
        return http.Response('{"notification_count":${read ? 0 : 1}}', 200);
      }
      return listResponse(read ? [] : [notification(1)]);
    }, onCount: counts.add);
    await tester.tap(find.byTooltip('标记已读'));
    await tester.pumpAndSettle();
    expect(find.text('Notification 1'), findsOneWidget);
    expect(find.textContaining('标记已读失败'), findsOneWidget);
    expect(counts.last, 1);
    fail = false;
    await tester.tap(find.byTooltip('标记已读'));
    await tester.pumpAndSettle();
    expect(find.text('Notification 1'), findsNothing);
    expect(counts.last, 0);
    expect(writes, 2);
  });

  testWidgets(
      'single read is disabled until acknowledgment and duplicate taps cannot write twice',
      (tester) async {
    final pending = Completer<http.Response>();
    var writes = 0;
    await showInbox(tester, (request) async {
      if (request.method == 'PATCH') {
        writes++;
        return pending.future;
      }
      if (request.url.path.endsWith('/count')) {
        return http.Response('{"notification_count":1}', 200);
      }
      return listResponse([notification(1)]);
    });
    await tester.tap(find.widgetWithText(ChoiceChip, '全部'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('标记已读'));
    await tester.pump();
    expect(find.text('Notification 1'), findsOneWidget);
    final readButton = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == '标记已读');
    expect(tester.widget<IconButton>(readButton).onPressed, isNull);
    await tester.tap(readButton);
    await tester.pump();
    pending.complete(http.Response('', 205));
    await tester.pumpAndSettle();
    expect(find.text('Notification 1'), findsOneWidget);
    expect(find.byTooltip('标记已读'), findsNothing);
    expect(writes, 1);
  });

  testWidgets(
      'bulk read confirms scope, handles failure and updates all row indicators',
      (tester) async {
    var fail = true;
    var writes = 0;
    var count = 2;
    await showInbox(tester, (request) async {
      if (request.method == 'PUT') {
        writes++;
        if (fail) return http.Response('{}', 500);
        count = 0;
        return http.Response('', 205);
      }
      if (request.url.path.endsWith('/count')) {
        return http.Response('{"notification_count":$count}', 200);
      }
      return listResponse([notification(1), notification(2)]);
    });
    await tester.tap(find.widgetWithText(ChoiceChip, '全部'));
    await tester.pumpAndSettle();
    final bulk = find.widgetWithText(TextButton, '全部已读');
    await tester.tap(bulk);
    await tester.pumpAndSettle();
    expect(find.textContaining('尚未加载'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.tap(bulk);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '全部已读'));
    await tester.pumpAndSettle();
    expect(find.textContaining('全部标记失败'), findsOneWidget);
    expect(find.byTooltip('标记已读'), findsNWidgets(2));
    fail = false;
    await tester.tap(bulk);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '全部已读'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('标记已读'), findsNothing);
    expect(find.text('0 条未读通知'), findsOneWidget);
    expect(find.text('Notification 1'), findsOneWidget);
  });

  testWidgets('failed refresh retains rows and explicit retry reloads page one',
      (tester) async {
    var fail = false;
    final pages = <String?>[];
    await showInbox(tester, (request) async {
      if (request.url.path.endsWith('/count')) {
        return http.Response('{"notification_count":1}', 200);
      }
      pages.add(request.url.queryParameters['page']);
      if (fail) return http.Response('{}', 500);
      return listResponse([notification(1)]);
    });
    fail = true;
    await tester.tap(find.byTooltip('刷新通知'));
    await tester.pumpAndSettle();
    expect(find.text('Notification 1'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(pages, ['1', '1', '1']);
    expect(find.text('重试'), findsNothing);
  });

  testWidgets('count failure preserves fetched notifications and can recover',
      (tester) async {
    var fail = true;
    await showInbox(tester, (request) async {
      if (request.url.path.endsWith('/count')) {
        return http.Response(
            fail ? '{}' : '{"notification_count":1}', fail ? 500 : 200);
      }
      return listResponse([notification(1)]);
    });
    expect(find.text('Notification 1'), findsOneWidget);
    expect(find.textContaining('未读计数暂不可用'), findsOneWidget);
    fail = false;
    await tester.tap(find.byTooltip('刷新通知'));
    await tester.pumpAndSettle();
    expect(find.text('1 条未读通知'), findsOneWidget);
  });

  testWidgets('late old filter response cannot overwrite current filter',
      (tester) async {
    final oldResponse = Completer<http.Response>();
    GiteeApi.setClientForTest(ApiClient(client: MockClient((request) async {
      if (request.url.path.endsWith('/count')) {
        return http.Response('{"notification_count":1}', 200);
      }
      if (request.url.queryParameters['unread'] == 'true') {
        return oldResponse.future;
      }
      return listResponse([notification(2, unread: false)]);
    })));
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NotificationsView())));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, '全部'));
    await tester.pumpAndSettle();
    oldResponse.complete(listResponse([notification(1)]));
    await tester.pumpAndSettle();
    expect(find.text('Notification 2'), findsOneWidget);
    expect(find.text('Notification 1'), findsNothing);
  });

  testWidgets('pagination retries the failed page and deduplicates overlap',
      (tester) async {
    var fail = true;
    final pages = <int>[];
    await showInbox(tester, (request) async {
      if (request.url.path.endsWith('/count')) {
        return http.Response('{"notification_count":21}', 200);
      }
      final page = int.parse(request.url.queryParameters['page']!);
      pages.add(page);
      if (page == 1) {
        return listResponse(
            List.generate(20, (index) => notification(index + 1)));
      }
      if (fail) return http.Response('{}', 500);
      return listResponse([notification(20), notification(21)]);
    });
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
    expect(pages, [1, 2]);
    fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(pages, [1, 2, 2]);
    expect(find.text('Notification 20'), findsOneWidget);
    expect(find.text('Notification 21'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swipe failure retains a row and successful retry removes it',
      (tester) async {
    var fail = true;
    var read = false;
    await showInbox(tester, (request) async {
      if (request.method == 'PATCH') {
        if (fail) return http.Response('{}', 500);
        read = true;
        return http.Response('', 205);
      }
      if (request.url.path.endsWith('/count')) {
        return http.Response('{"notification_count":${read ? 0 : 1}}', 200);
      }
      return listResponse(read ? [] : [notification(1)]);
    });
    await tester.drag(
        find.byKey(const ValueKey('notification_1')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Notification 1'), findsOneWidget);
    expect(find.textContaining('标记已读失败'), findsOneWidget);
    fail = false;
    await tester.drag(
        find.byKey(const ValueKey('notification_1')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Notification 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unread removal rebases pagination before the next page',
      (tester) async {
    final pages = <int>[];
    var read = false;
    await showInbox(tester, (request) async {
      if (request.method == 'PATCH') {
        read = true;
        return http.Response('', 205);
      }
      if (request.url.path.endsWith('/count')) {
        return http.Response('{"notification_count":${read ? 20 : 21}}', 200);
      }
      pages.add(int.parse(request.url.queryParameters['page']!));
      return listResponse(
          List.generate(20, (index) => notification(index + (read ? 2 : 1))));
    });
    await tester.tap(find.byTooltip('标记已读').first);
    await tester.pumpAndSettle();
    expect(pages, [1, 1]);
    expect(find.text('Notification 1'), findsNothing);
    expect(find.text('Notification 21'), findsOneWidget);
  });

  testWidgets(
      'inbox fits a narrow Android display with enlarged text and dark theme',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await showInbox(tester, (request) async {
      if (request.url.path.endsWith('/count')) {
        return http.Response('{"notification_count":1}', 200);
      }
      return listResponse([notification(1)]);
    }, mode: ThemeMode.dark);
    expect(find.text('Notification 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
