import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gitee_client/main.dart';
import 'package:gitee_client/models/user.dart';
import 'package:gitee_client/pages/profile_page.dart';
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

    await settings.setThemeMode(AppThemeMode.dark);
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets('profile shortcuts fit a narrow Android viewport',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: AppSettingsScope(
              settings: AppSettingsProvider(),
              child: ProfilePage(
                user: User(
                  id: 1,
                  login: 'alice',
                  name: 'Alice',
                  avatarUrl: '',
                  bio: '',
                  publicRepos: 4,
                  followers: 2,
                  following: 3,
                ),
                onLogout: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('我的组织'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
