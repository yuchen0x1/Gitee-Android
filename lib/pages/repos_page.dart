import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../models/repo.dart';
import '../providers/app_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_surface.dart';
import '../widgets/paged_list_view.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/repo_card.dart';
import 'create_repo_page.dart';
import 'my_issues_page.dart';
import 'repo_detail_page.dart';
import 'starred_repos_page.dart';
import 'subscriptions_page.dart';
import 'following_page.dart';

/// 我的仓库列表页（顶部支持最近浏览快捷横向列表）。
class ReposPage extends StatefulWidget {
  const ReposPage({super.key});

  @override
  State<ReposPage> createState() => _ReposPageState();
}

class _ReposPageState extends State<ReposPage> {
  final GlobalKey<PagedListViewState<Repo>> _listKey =
      GlobalKey<PagedListViewState<Repo>>();

  Future<void> _createRepo() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateRepoPage()),
    );
    if (created != true || !mounted) return;
    await _listKey.currentState?.refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('仓库已创建')),
    );
  }

  void _openRepo(String fullName) {
    final parts = fullName.split('/');
    if (parts.length < 2) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RepoDetailPage(owner: parts[0], repo: parts[1]),
      ),
    );
  }

  /// 仓库页顶部快捷入口：快速跟进 Issue / Star / 订阅 / 关注。
  Widget _buildQuickEntries(BuildContext context) {
    final entries = <(IconData, String, Widget Function())>[
      (Icons.bug_report_outlined, '我的 Issue', () => const MyIssuesPage()),
      (Icons.star_outline, '我的 Star', () => const StarredReposPage()),
      (Icons.notifications_active_outlined, '我的订阅', () => const SubscriptionsPage()),
      (Icons.favorite_outline, '我的关注', () => const FollowingPage()),
    ];
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final (icon, label, page) = entries[index];
          return PressableScale(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => page())),
            child: Container(
              width: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryRed.withValues(alpha: 0.10),
                    AppColors.primaryLight.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryRed.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.primaryRed, size: 22),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final recents = settings.recentRepos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('仓库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '创建仓库',
            onPressed: _createRepo,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildQuickEntries(context),
          if (recents.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: GlassSurface(
                simple: true,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.history_rounded, size: 14, color: AppColors.primaryRed),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '最近浏览',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                          ),
                          const Spacer(),
                          InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => settings.clearRecentRepos(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                '清空',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: recents.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final fullName = recents[index];
                          final shortName = fullName.split('/').last;
                          return ActionChip(
                            avatar: const Icon(Icons.folder_outlined, size: 14),
                            label: Text(shortName),
                            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            tooltip: fullName,
                            onPressed: () => _openRepo(fullName),
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: PagedListView<Repo>(
              key: _listKey,
              loadPage: (page) => GiteeApi.getUserRepos(page: page, perPage: 20),
              itemBuilder: (context, repo) => RepoCard(repo: repo),
              emptyIcon: Icons.folder_open,
              emptyTitle: '暂无仓库',
              emptySubtitle: '去 Gitee 创建仓库后下拉刷新即可看到',
            ),
          ),
        ],
      ),
    );
  }
}

