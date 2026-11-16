import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gitee_client/api/so_search_api.dart';
import 'package:gitee_client/pages/search_page.dart';
import 'package:gitee_client/providers/app_settings.dart';

void main() {
  testWidgets('clear cancels debounce and ignores in-flight search',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final ready = Completer<http.Response>();
    var calls = 0;
    final api = SoSearchApi(client: MockClient((_) {
      calls++;
      return ready.future;
    }));
    await tester.pumpWidget(MaterialApp(
        home: AppSettingsScope(
            settings: AppSettingsProvider(),
            child: SearchPage(repoSearch: api))));
    await tester.enterText(find.byType(SearchBar), 'first');
    await tester.pump(const Duration(milliseconds: 401));
    expect(calls, 1);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    ready.complete(http.Response('{"hits":{"hits":[]}}', 200));
    await tester.pumpAndSettle();
    expect(find.text('热门搜索'), findsOneWidget);
    expect(find.text('没有找到相关内容'), findsNothing);
    await tester.enterText(find.byType(SearchBar), 'first');
    await tester.pump(const Duration(milliseconds: 401));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('没有找到相关内容'), findsOneWidget);
    await tester.enterText(find.byType(SearchBar), 'second');
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox());
  });
}
