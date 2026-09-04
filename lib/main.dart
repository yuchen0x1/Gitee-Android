import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'auth/auth_store.dart';
import 'auth/app_lock.dart';
import 'api/gitee_api.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'providers/app_settings.dart';
import 'theme/app_theme.dart';
import 'pages/ai_settings_page.dart';
import 'utils/deep_link.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
bool _handlingUnauthorized = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GiteeApi.onUnauthorized = () async {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    await AuthStore.clear();
    GiteeApi.clearToken();
    final navigator = rootNavigatorKey.currentState;
    if (navigator != null) {
      await navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
    _handlingUnauthorized = false;
  };
  final settings = await AppSettingsProvider.load();
  await AppLock.load();
  await AiSettingsPage.loadFromPrefs();
  runApp(GiteeApp(settings: settings));
  _setupDeepLinks();
}

void _setupDeepLinks() {
  final appLinks = AppLinks();
  appLinks.getInitialLink().then((uri) {
    if (uri == null) return;
    Future.delayed(
      const Duration(milliseconds: 500),
      () => handleDeepLink(uri, rootNavigatorKey),
    );
  });
  appLinks.uriLinkStream.listen((uri) => handleDeepLink(uri, rootNavigatorKey));
}

class GiteeApp extends StatelessWidget {
  final AppSettingsProvider settings;

  const GiteeApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => AppSettingsScope(
        settings: settings,
        child: AppLockGate(
          child: MaterialApp(
            title: 'Gitee Client',
            navigatorKey: rootNavigatorKey,
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            home: const SplashPage(),
          ),
        ),
      ),
    );
  }
}

/// 在 App 之上叠加生物识别锁屏。
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (AppLock.enabled && !AppLock.unlocked)
            AppLockScreen(onUnlocked: () => setState(() {})),
        ],
      ),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final token = await AuthStore.readToken();
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      GiteeApi.setToken(token);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryRed, AppColors.primaryDark],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'G',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Gitee Client',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A mobile client for Gitee',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 44),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
