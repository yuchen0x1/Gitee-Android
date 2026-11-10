import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gitee_client/pages/onboarding_page.dart';
import 'package:gitee_client/providers/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('引导最后一步使用准确的登录操作文案', (tester) async {
    final semantics = tester.ensureSemantics();
    final settings = AppSettingsProvider();
    var finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppSettingsScope(
          settings: settings,
          child: OnboardingPage(onFinish: () => finished++),
        ),
      ),
    );

    expect(find.text('继续'), findsOneWidget);
    expect(find.bySemanticsLabel('引导进度'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('引导进度'))
          .getSemanticsData()
          .value,
      '第 1 页，共 3 页',
    );
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    expect(find.text('前往登录'), findsOneWidget);
    await tester.tap(find.text('前往登录'));
    await tester.pump();
    expect(finished, 1);
    expect(settings.onboardingSeen, isTrue);
    semantics.dispose();
  });

  testWidgets('窄屏布局可显示引导内容和操作按钮', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: AppSettingsScope(
              settings: AppSettingsProvider(),
              child: const OnboardingPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('跟进动态'), findsOneWidget);
    expect(find.text('继续'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
