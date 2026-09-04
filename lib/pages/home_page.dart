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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DynamicsPage(
            userLogin: _user?.login,
            onUnreadCountChanged: (count) {
              if (mounted) setState(() => _unreadCount = count);
            },
          ),
          const ReposPage(),
          const SearchPage(),
          ProfilePage(user: _user, onLogout: _logout, onRefresh: _refresh),
        ],
      ),
      bottomNavigationBar: GlassNavigationBar(
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
