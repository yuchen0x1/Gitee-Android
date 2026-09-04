import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitee_client/utils/deep_link.dart';

void main() {
  testWidgets('parses custom scheme host as the deep-link route',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
      ),
    );

    handleDeepLink(Uri.parse('gitee://user/alice'), navigatorKey);
    await tester.pumpAndSettle();

    expect(find.text('alice'), findsOneWidget);
  });
}
