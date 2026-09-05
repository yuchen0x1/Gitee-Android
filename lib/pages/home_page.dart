import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../auth/auth_store.dart';
import '../api/gitee_api.dart';
import '../models/user.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_badge.dart';
import '../widgets/glass_surface.dart';
import '../widgets/update_dialog.dart';
import 'dynamics_page.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'repos_page.dart';
import 'search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  User? _user;
  int _unreadCount = 0;
  bool _handlingUnauthorized = false;
  bool _automaticUpdateCheckStarted = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadNotificationCount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_automaticUpdateCheckStarted) {
        _automaticUpdateCheckStarted = true;
        unawaited(_checkForUpdate(showErrors: false));
      }
    });
  }

  Future<void> _checkForUpdate({required bool showErrors}) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final update = await UpdateService.shared.checkForUpdate(
        currentVersion: info.version,
      );
      if (!mounted || update == null) {
        if (mounted && showErrors) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前已是最新版本')),
          );
        }
        return;
      }
      await showAppUpdateDialog(
        context,
        update,
        currentVersion: info.version,
      );
    } catch (_) {
      if (mounted && showErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂时无法检查更新，请稍后重试')),
        );
      }
    }
  }

  void _handleUnauthorized() {
    if (!mounted || _handlingUnauthorized) return;
    _handlingUnauthorized = true;
    unawaited(AuthStore.clear());
    GiteeApi.clearToken();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _refresh() async {
    await Future.wait([_loadUser(), _loadNotificationCount()]);
  }

  Future<void> _loadNotificationCount() async {
    try {
      final count = await GiteeApi.getNotificationCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {}
  }

  Future<void> _loadUser() async {
    try {
      final user = await GiteeApi.getCurrentUser();
      if (mounted) {
        setState(() => _user = user);
        // 登录后自动保存到多账号列表
        await AuthStore.addAccount(
          username: user.login,
          token: GiteeApi.token ?? '',
          avatarUrl: user.avatarUrl,
        );
      }
    } catch (_) {
      if (mounted && GiteeApi.token == null) _handleUnauthorized();
    }
  }

  Future<void> _logout() async {
    await AuthStore.clear();
    GiteeApi.clearToken();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  static const _desktopBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DynamicsPage(
        userLogin: _user?.login,
        onUnreadCountChanged: (count) {
          if (mounted) setState(() => _unreadCount = count);
        },
      ),
      const ReposPage(),
      const SearchPage(),
      ProfilePage(user: _user, onLogout: _logout, onRefresh: _refresh),
    ];
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= _desktopBreakpoint;
          final content = IndexedStack(index: _currentIndex, children: pages);
          if (isDesktop) {
            // 桌面宽屏：左侧导航栏 + 居中限宽内容列，避免列表被拉伸变形。
            return Row(
              children: [
                _DesktopNavRail(
                  currentIndex: _currentIndex,
                  unreadCount: _unreadCount,
                  onDestinationSelected: (i) =>
                      setState(() => _currentIndex = i),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: content,
                    ),
                  ),
                ),
              ],
            );
          }
          // 窄屏（手机）：保持底部导航。
          return Column(
            children: [
              Expanded(child: content),
              GlassNavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (i) => setState(() => _currentIndex = i),
                destinations: [
                  NavigationDestination(
                    icon: _navIcon(Icons.dynamic_feed_outlined),
                    selectedIcon: _navIcon(Icons.dynamic_feed),
                    label: '动态',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder, color: AppColors.primaryRed),
                    label: '仓库',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.search),
                    selectedIcon: Icon(Icons.search, color: AppColors.primaryRed),
                    label: '搜索',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person, color: AppColors.primaryRed),
                    label: '我的',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _navIcon(IconData icon) {
    return Stack(
      children: [
        Icon(icon),
        if (_unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: AppBadge(count: _unreadCount),
          ),
      ],
    );
  }
}

/// 桌面端左侧导航栏：与手机底部导航同源的玻璃质感 + 品牌红指示。
class _DesktopNavRail extends StatelessWidget {
  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onDestinationSelected;

  const _DesktopNavRail({
    required this.currentIndex,
    required this.unreadCount,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.6),
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryLight, AppColors.primaryRed],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cloud_outlined,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: NavigationRail(
                selectedIndex: currentIndex,
                onDestinationSelected: onDestinationSelected,
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.transparent,
                indicatorColor: AppColors.primaryRed.withValues(alpha: 0.12),
                selectedIconTheme:
                    const IconThemeData(color: AppColors.primaryRed),
                selectedLabelTextStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryRed,
                ),
                unselectedIconTheme:
                    const IconThemeData(color: AppColors.textTertiary),
                unselectedLabelTextStyle: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
                destinations: [
                  NavigationRailDestination(
                    icon: _railIcon(Icons.dynamic_feed_outlined),
                    selectedIcon: _railIcon(Icons.dynamic_feed),
                    label: const Text('动态'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder),
                    label: Text('仓库'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.search),
                    selectedIcon: Icon(Icons.search),
                    label: Text('搜索'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: Text('我的'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _railIcon(IconData icon) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (unreadCount > 0)
          Positioned(
            right: -4,
            top: -3,
            child: AppBadge(count: unreadCount),
          ),
      ],
    );
  }
}
