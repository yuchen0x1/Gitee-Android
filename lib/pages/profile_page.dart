import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../auth/app_lock.dart';
import '../auth/auth_store.dart';
import '../api/gitee_api.dart';
import '../models/user.dart';
import '../providers/app_settings.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';
import '../widgets/glass_surface.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/update_dialog.dart';
import 'followers_page.dart';
import 'ai_settings_page.dart';
import 'app_changelog_page.dart';
import 'demo_page.dart';
import 'following_page.dart';
import 'my_issues_page.dart';
import 'starred_repos_page.dart';
import 'subscriptions_page.dart';
import 'user_repos_page.dart';
import 'organizations_page.dart';
import 'gist_list_page.dart';
import 'ssh_keys_page.dart';

class ProfilePage extends StatefulWidget {
  final User? user;
  final VoidCallback onLogout;
  final Future<void> Function()? onRefresh;

  const ProfilePage({
    super.key,
    this.user,
    required this.onLogout,
    this.onRefresh,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<void> _toggleAppLock(bool value) async {
    if (value && !await AppLock.canUseBiometrics) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备不支持生物识别')),
        );
      }
      return;
    }
    await AppLock.setEnabled(value);
    if (mounted) setState(() {});
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final update = await UpdateService.shared.checkForUpdate(
        currentVersion: info.version,
        forceRefresh: true,
      );
      if (!mounted) return;
      if (update == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已是最新版本')),
        );
        return;
      }
      await showAppUpdateDialog(
        context,
        update,
        currentVersion: info.version,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂时无法检查更新，请稍后重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = AppSettingsScope.of(context);
    final user = widget.user;
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: user == null
          ? const SkeletonList(itemCount: 4)
          : RefreshIndicator(
              color: AppColors.primaryRed,
              onRefresh: () async => widget.onRefresh?.call(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  _buildHeader(user, theme),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStats(user),
                        const SizedBox(height: 20),
                        Text('快捷入口', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _buildQuickGrid(user),
                        const SizedBox(height: 20),
                        Text('设置', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        GlassSurface(
                          child: Material(
                            type: MaterialType.transparency,
                            child: Column(
                              children: [
                                SwitchListTile(
                                  secondary: const Icon(
                                      Icons.dark_mode_outlined,
                                      color: AppColors.primaryRed),
                                  title: const Text('深色模式'),
                                  value: settings.darkMode,
                                  onChanged: (value) =>
                                      settings.setDarkMode(value),
                                ),
                                const Divider(),
                                SwitchListTile(
                                  secondary: const Icon(Icons.fingerprint,
                                      color: AppColors.primaryRed),
                                  title: const Text('生物识别解锁'),
                                  value: AppLock.enabled,
                                  onChanged: _toggleAppLock,
                                ),
                                const Divider(),
                                ListTile(
                                  leading: const Icon(Icons.help_outline,
                                      color: AppColors.primaryRed),
                                  title: const Text('账号管理'),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: AppColors.textTertiary),
                                  onTap: _showAccountManager,
                                ),
                                const Divider(),
                                ListTile(
                                  leading: const Icon(Icons.code_outlined,
                                      color: AppColors.primaryRed),
                                  title: const Text('代码片段'),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: AppColors.textTertiary),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => const GistListPage()),
                                  ),
                                ),
                                const Divider(),
                                ListTile(
                                  leading: const Icon(Icons.vpn_key_outlined,
                                      color: AppColors.primaryRed),
                                  title: const Text('SSH 公钥'),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: AppColors.textTertiary),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => const SshKeysPage()),
                                  ),
                                ),
                                const Divider(),
                                ListTile(
                                  leading: const Icon(Icons.help_outline,
                                      color: AppColors.primaryRed),
                                  title: const Text('使用指南'),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: AppColors.textTertiary),
                                  onTap: _openDemo,
                                ),
                                const Divider(),
                                ListTile(
                                  leading: const Icon(Icons.smart_toy_outlined,
                                      color: AppColors.primaryRed),
                                  title: const Text('AI 设置'),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: AppColors.textTertiary),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => const AiSettingsPage()),
                                  ),
                                ),
                                const Divider(),
                                ListTile(
                                  leading: const Icon(
                                      Icons.cleaning_services_outlined,
                                      color: AppColors.primaryRed),
                                  title: const Text('清除缓存'),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: AppColors.textTertiary),
                                  onTap: _clearCache,
                                ),
                                const Divider(),
                                ListTile(
                                  leading: const Icon(Icons.system_update_alt,
                                      color: AppColors.primaryRed),
                                  title: const Text('检查更新'),
                                  subtitle: const Text('从官方发布页获取最新版本'),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: AppColors.textTertiary),
                                  onTap: _checkForUpdate,
                                ),
                                const Divider(),
                                ListTile(
                                  leading: const Icon(Icons.history_edu,
                                      color: AppColors.primaryRed),
                                  title: const Text('更新日志'),
                                  subtitle: const Text('查看各版本的功能与修复'),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: AppColors.textTertiary),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => const AppChangelogPage()),
                                  ),
                                ),
                                const Divider(),
                                ListTile(
                                  leading: const Icon(Icons.info_outline,
                                      color: AppColors.primaryRed),
                                  title: const Text('关于'),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: AppColors.textTertiary),
                                  onTap: _showAbout,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: widget.onLogout,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryRed,
                              side:
                                  const BorderSide(color: AppColors.primaryRed),
                            ),
                            icon: const Icon(Icons.logout),
                            label: const Text('退出登录'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(User user, ThemeData theme) {
    return GlassSurface(
      borderRadius: BorderRadius.zero,
      tint: AppColors.primaryRed.withValues(alpha: 0.82),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: AppAvatar(url: user.avatarUrl, size: 64, radius: 32),
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text('@${user.login}',
              style: const TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 10),
          Text(
            user.bio,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(User user) {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _StatItem(
                label: '仓库', value: user.publicRepos, onTap: _openMyRepos),
            _StatItem(
                label: '粉丝', value: user.followers, onTap: _openFollowers),
            _StatItem(
                label: '关注', value: user.following, onTap: _openFollowing),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickGrid(User user) {
    final items = [
      _QuickItem(
          icon: Icons.folder_outlined, label: '我的仓库', onTap: _openMyRepos),
      _QuickItem(
          icon: Icons.star_outline, label: '我的 Star', onTap: _openStarred),
      _QuickItem(
          icon: Icons.favorite_outline, label: '我的关注', onTap: _openFollowing),
      _QuickItem(
          icon: Icons.people_outline, label: '我的粉丝', onTap: _openFollowers),
      _QuickItem(
          icon: Icons.bug_report_outlined,
          label: '我的 Issue',
          onTap: _openMyIssues),
      _QuickItem(
          icon: Icons.notifications_active_outlined,
          label: '我的订阅',
          onTap: _openSubscriptions),
      _QuickItem(
          icon: Icons.business_outlined,
          label: '我的组织',
          onTap: _openOrganizations),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.8,
      children: items.map((item) {
        return PressableScale(
          onTap: item.onTap,
          child: GlassSurface(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: item.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(item.icon, color: AppColors.primaryRed, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(item.label,
                            style: Theme.of(context).textTheme.titleMedium)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _openMyRepos() {
    final user = widget.user;
    if (user == null) return;
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UserReposPage(username: user.login)));
  }

  void _openStarred() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const StarredReposPage()));
  }

  void _openFollowing() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FollowingPage()));
  }

  void _openFollowers() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FollowersPage()));
  }

  void _openMyIssues() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MyIssuesPage()));
  }

  void _openSubscriptions() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SubscriptionsPage()));
  }

  void _openOrganizations() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrganizationsPage()),
    );
  }

  void _clearCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('图片缓存已清除')),
    );
  }

  /// 打开应用内使用指南，集中说明令牌权限与主要工作流。

  Future<void> _showAccountManager() async {
    final accounts = await AuthStore.readAccounts();
    final currentToken = GiteeApi.token;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('账号管理', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (accounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('暂无已保存账号'),
                ),
              ...accounts.map((account) {
                final isCurrent = account['token'] == currentToken;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundImage: account['avatarUrl'] != null &&
                            account['avatarUrl']!.isNotEmpty
                        ? NetworkImage(account['avatarUrl']!)
                        : null,
                    child: account['avatarUrl'] == null ||
                            account['avatarUrl']!.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(account['username'] ?? ''),
                  trailing: isCurrent
                      ? const Chip(label: Text('当前'))
                      : TextButton(
                          onPressed: () async {
                            final ok = await AuthStore.switchAccount(
                              account['username']!,
                            );
                            if (!ok) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('账号凭据已失效，请重新登录')),
                                );
                              }
                              return;
                            }
                            if (context.mounted) Navigator.pop(context);
                            final activeToken = await AuthStore.readToken();
                            if (activeToken == null || activeToken.isEmpty) {
                              return;
                            }
                            GiteeApi.setToken(activeToken);
                            await widget.onRefresh?.call();
                          },
                          child: const Text('切换'),
                        ),
                );
              }),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add, color: AppColors.primaryRed),
                title: const Text('添加新账号'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onLogout.call();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDemo() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const DemoPage()));
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gitee Client'),
        content: const Text(
          'Gitee Client provides repository browsing, Issue, Pull Request, notification, and activity workflows.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openDemo();
            },
            child: const Text('使用指南'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onTap;

  const _StatItem(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Text(value.toString(),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _QuickItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickItem(
      {required this.icon, required this.label, required this.onTap});
}
