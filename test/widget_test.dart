import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gitee_client/main.dart';
import 'package:gitee_client/providers/app_settings.dart';

void main() {
  testWidgets('Gitee Client renders splash screen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final settings = await AppSettingsProvider.load();

    await tester.pumpWidget(GiteeApp(settings: settings));
    expect(find.text('Gitee Client'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
  });

  testWidgets('theme changes when app settings change',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final settings = await AppSettingsProvider.load();
    await tester.pumpWidget(GiteeApp(settings: settings));

    final textFinder = find.text('Gitee Client');
    expect(
      Theme.of(tester.element(textFinder)).brightness,
      Brightness.light,
    );

    await settings.setDarkMode(true);
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });
}
