import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/gitee_api.dart';
import '../models/file.dart';
import '../services/offline_cache.dart';
import '../models/repo.dart';
import '../providers/app_settings.dart';
import '../theme/app_theme.dart';
import '../utils/launch_url.dart';
import '../utils/error_message.dart';
import '../widgets/app_image.dart';
import '../widgets/app_markdown.dart';
import '../widgets/glass_surface.dart';
import '../widgets/branch_selector.dart';
import '../widgets/commit_list_view.dart';
import '../widgets/issue_list_view.dart';
import '../widgets/issue_composer.dart';
import '../widgets/pull_request_list_view.dart';
import '../widgets/pr_composer.dart';
import '../widgets/release_list_view.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_views.dart';
import '../widgets/time_format.dart';
import 'code_view_page.dart';
import 'commit_detail_page.dart';
import 'issue_detail_page.dart';
import 'pr_detail_page.dart';
import 'release_detail_page.dart';
import 'repo_events_page.dart';
import 'repo_file_browser_page.dart';
import 'repo_tools_page.dart';
import 'repo_subscribers_page.dart';

/// 仓库详情页：概览、文件、Issues、Commits、Pull Requests、版本六个 Tab。
class RepoDetailPage extends StatefulWidget {
  final String owner;
  final String repo;

  const RepoDetailPage({super.key, required this.owner, required this.repo});

  @override
  State<RepoDetailPage> createState() => _RepoDetailPageState();
}

class _RepoDetailPageState extends State<RepoDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Repo? _repo;
  String? _readme;
  List<String> _topics = [];
  List<String> _branches = [];
  String _branch = '';
  bool _isStarred = false;
  bool _isSubscribed = false;
  bool _loading = true;
  String? _error;
  bool _readmeLoading = false;
  String? _readmeError;
  bool _repoOffline = false;
  bool _readmeOffline = false;
  int _loadVersion = 0;
  int _issuesVersion = 0;
  int _pullRequestsVersion = 0;
  final GlobalKey<_FilesTabState> _filesTabKey = GlobalKey<_FilesTabState>();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
    _loadAll();
  }

  /// 仅在 Tab 切换完成后刷新创建按钮，避免动画过程重复重建页面。
  void _onTabChanged() {
    if (!_tabCtrl.indexIsChanging && mounted) setState(() {});
  }

  /// 先显示仓库主体，附属接口分别加载，避免单个接口让整页失效。
  Future<void> _loadAll() async {
    final loadVersion = ++_loadVersion;
    setState(() {
      _loading = true;
      _error = null;
      _readme = null;
      _readmeError = null;
      _readmeLoading = false;
      _repoOffline = false;
      _readmeOffline = false;
      _topics = [];
      _branches = [];
    });
    try {
      final repo = await GiteeApi.getRepoDetail(widget.owner, widget.repo);
      unawaited(OfflineCache.write(
        key: OfflineCache.key(
          token: GiteeApi.token,
          type: 'repo',
          parts: [widget.owner, widget.repo],
        ),
        value: repo.toJson(),
      ));
      if (!mounted || loadVersion != _loadVersion) return;
      final initialBranch = _branch.isNotEmpty ? _branch : repo.defaultBranch;
      setState(() {
        _repo = repo;
        _repoOffline = false;
        _branch = initialBranch;
        _loading = false;
      });
      if (mounted) {
        AppSettingsScope.of(context).addRecentRepo(repo.fullName);
      }
      unawaited(_loadSupplementaryData(repo, loadVersion));
    } catch (e) {
      final cached = await OfflineCache.read(OfflineCache.key(
        token: GiteeApi.token,
        type: 'repo',
        parts: [widget.owner, widget.repo],
      ));
      final value = cached?.value;
      if (value is Map) {
        final repo = Repo.fromJson(Map<String, dynamic>.from(value));
        if (!mounted || loadVersion != _loadVersion) return;
        final initialBranch = _branch.isNotEmpty ? _branch : repo.defaultBranch;
        setState(() {
          _repo = repo;
          _repoOffline = true;
          _branch = initialBranch;
          _loading = false;
          _error = null;
        });
        if (mounted) {
          AppSettingsScope.of(context).addRecentRepo(repo.fullName);
        }
        unawaited(_loadSupplementaryData(repo, loadVersion));
        return;
      }
      if (mounted && loadVersion == _loadVersion) {
        setState(() {
          _loading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  /// 分支、README 和用户状态均为增强信息，失败时不影响仓库主体。
  Future<void> _loadSupplementaryData(Repo repo, int loadVersion) async {
    var branch = _branch.isNotEmpty ? _branch : repo.defaultBranch;
    try {
      final branches = await GiteeApi.getBranches(widget.owner, widget.repo);
      if (!mounted || loadVersion != _loadVersion) return;
      if (branches.isNotEmpty && !branches.contains(branch)) {
        branch = branches.first;
      }
      setState(() {
        _branches = branches;
        _branch = branch;
      });
    } catch (_) {
      // 分支请求失败时继续使用仓库默认分支读取 README。
    }

    if (!mounted || loadVersion != _loadVersion) return;
    unawaited(_loadReadme(branch, loadVersion: loadVersion));
    unawaited(_loadTopics(loadVersion));
    unawaited(_loadUserRepositoryState(loadVersion));
  }

  /// Topic 标签属于增强信息，失败或为空时不展示，不影响主体内容。
  Future<void> _loadTopics(int loadVersion) async {
    try {
      final topics = await GiteeApi.getRepoTopics(widget.owner, widget.repo);
      if (!mounted || loadVersion != _loadVersion) return;
      setState(() => _topics = topics);
    } catch (_) {
      // Topics 接口异常时保持空列表，页面照常渲染。
    }
  }

  /// Star 与订阅状态仅影响操作按钮，不应阻断详情内容。
  Future<void> _loadUserRepositoryState(int loadVersion) async {
    try {
      final states = await Future.wait([
        GiteeApi.checkStarred(widget.owner, widget.repo),
        GiteeApi.checkSubscribed(widget.owner, widget.repo),
      ]);
      if (!mounted || loadVersion != _loadVersion) return;
      setState(() {
        _isStarred = states[0];
        _isSubscribed = states[1];
      });
    } catch (_) {
      // 未登录或状态接口异常时，保留默认的未选中状态。
    }
  }

  Future<void> _loadReadme(String branch, {required int loadVersion}) async {
    if (!mounted || loadVersion != _loadVersion) return;
    setState(() {
      _readmeLoading = true;
      _readmeError = null;
      _readme = null;
    });
    try {
      final readme = await GiteeApi.getRepoReadme(
        widget.owner,
        widget.repo,
        branch: branch,
      );
      unawaited(OfflineCache.write(
        key: OfflineCache.key(
          token: GiteeApi.token,
          type: 'readme',
          parts: [widget.owner, widget.repo, branch],
        ),
        value: readme,
      ));
      if (!mounted || loadVersion != _loadVersion || _branch != branch) return;
      setState(() {
        _readme = readme;
        _readmeOffline = false;
      });
    } catch (_) {
      final cached = await OfflineCache.read(OfflineCache.key(
        token: GiteeApi.token,
        type: 'readme',
        parts: [widget.owner, widget.repo, branch],
      ));
      final value = cached?.value;
      if (value is String &&
          mounted &&
          loadVersion == _loadVersion &&
          _branch == branch) {
        setState(() {
          _readme = value;
          _readmeOffline = true;
        });
      } else if (!mounted || loadVersion != _loadVersion || _branch != branch) {
        return;
      } else {
        setState(() => _readmeError = 'README 暂不可用');
      }
    } finally {
      if (mounted && loadVersion == _loadVersion && _branch == branch) {
        setState(() => _readmeLoading = false);
      }
    }
  }

  Future<void> _onBranchChanged(String branch) async {
    if (branch == _branch) return;
    setState(() {
      _branch = branch;
      _readme = null;
      _readmeOffline = false;
    });
    await _loadReadme(branch, loadVersion: _loadVersion);
  }

  Future<void> _toggleStar() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final ok = _isStarred
          ? await GiteeApi.unstarRepo(widget.owner, widget.repo)
          : await GiteeApi.starRepo(widget.owner, widget.repo);
      if (ok && mounted) {
        HapticFeedback.mediumImpact();
        setState(() => _isStarred = !_isStarred);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isStarred ? '已 Star' : '已取消 Star')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _toggleSubscribe() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final ok = _isSubscribed
          ? await GiteeApi.unsubscribeRepo(widget.owner, widget.repo)
          : await GiteeApi.subscribeRepo(widget.owner, widget.repo);
      if (ok && mounted) {
        setState(() => _isSubscribed = !_isSubscribed);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isSubscribed ? '已订阅该仓库' : '已取消订阅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _openBrowser() async {
    final repo = _repo;
    if (repo == null || repo.htmlUrl.isEmpty) return;
    await launchExternalUrl(repo.htmlUrl);
  }

  /// 在独立时间线中展示官方 Events 接口返回的仓库活动。
  void _openEvents() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepoEventsPage(owner: widget.owner, repo: widget.repo),
      ),
    );
  }

  /// 根据当前仓库页签打开对应创建面板，并重建列表以获取最新数据。
  Future<void> _createForCurrentTab() async {
    final isIssueTab = _tabCtrl.index == 2;
    final created = isIssueTab
        ? await showCreateIssueSheet(
            context,
            owner: widget.owner,
            repo: widget.repo,
          )
        : await showCreatePullRequestSheet(
            context,
            owner: widget.owner,
            repo: widget.repo,
          );
    if (!mounted || !created) return;
    setState(() {
      if (isIssueTab) {
        _issuesVersion++;
      } else {
        _pullRequestsVersion++;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isIssueTab ? 'Issue 已创建' : 'Pull Request 已创建')),
    );
  }

  /// 子页面返回后刷新仓库状态与当前页列表。
  Future<void> _refreshAfterReturn(int currentTab) async {
    if (!mounted || _repo == null) return;
    setState(() {
      if (currentTab == 2) {
        _issuesVersion++;
      } else if (currentTab == 4) {
        _pullRequestsVersion++;
      }
    });
    final repo = _repo!;
    unawaited(_loadSupplementaryData(repo, _loadVersion));
    if (currentTab == 1) {
      final filesState = _filesTabKey.currentState;
      if (filesState != null) await filesState.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_repo == null && _loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.repo)),
        body: const SkeletonList(variant: SkeletonVariant.issueRow),
      );
    }
    if (_repo == null && _error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.repo)),
        body: ErrorState(message: _error!, onRetry: _loadAll),
      );
    }
    final repo = _repo!;
    return Scaffold(
      appBar: AppBar(
        title: Text(repo.fullName, overflow: TextOverflow.ellipsis),
        actions: [
          if (_repoOffline || _readmeOffline)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.cloud_off_outlined, size: 19),
            ),
          IconButton(
            icon: Icon(
              _isStarred ? Icons.star : Icons.star_border,
              color: _isStarred ? AppColors.starColor : null,
            ),
            tooltip: _isStarred ? '取消 Star' : 'Star',
            onPressed: _toggleStar,
          ),
          IconButton(
            icon: Icon(
              _isSubscribed
                  ? Icons.notifications_active
                  : Icons.notifications_none,
              color: _isSubscribed ? AppColors.primaryRed : null,
            ),
            tooltip: _isSubscribed ? '取消订阅' : '订阅',
            onPressed: _toggleSubscribe,
          ),
          PopupMenuButton<String>(
            tooltip: '更多操作',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'events':
                  _openEvents();
                  break;
                case 'tools':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RepoToolsPage(
                        owner: widget.owner,
                        repo: widget.repo,
                        defaultBranch: repo.defaultBranch,
                      ),
                    ),
                  );
                  break;
                case 'browser':
                  _openBrowser();
                  break;
                case 'refresh':
                  _loadAll();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'events',
                child: _RepoMenuItem(
                  icon: Icons.timeline_outlined,
                  label: '仓库动态',
                ),
              ),
              PopupMenuItem(
                value: 'tools',
                child: _RepoMenuItem(
                  icon: Icons.settings_outlined,
                  label: '仓库能力中心',
                ),
              ),
              PopupMenuItem(
                value: 'browser',
                child: _RepoMenuItem(
                  icon: Icons.open_in_browser,
                  label: '在浏览器中打开',
                ),
              ),
              PopupMenuItem(
                value: 'refresh',
                child: _RepoMenuItem(icon: Icons.refresh, label: '刷新'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '概览'),
            Tab(text: '文件'),
            Tab(text: 'Issues'),
            Tab(text: 'Commits'),
            Tab(text: 'PR'),
            Tab(text: '版本'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _OverviewTab(
            repo: repo,
            owner: widget.owner,
            repoName: widget.repo,
            topics: _topics,
            readme: _readme,
            branch: _branch,
            readmeLoading: _readmeLoading,
            readmeError: _readmeError,
            onRetryReadme: () =>
                _loadReadme(_branch, loadVersion: _loadVersion),
          ),
          _FilesTab(
            key: _filesTabKey,
            owner: widget.owner,
            repo: widget.repo,
            branch: _branch,
            branches: _branches,
            onBranchChanged: _onBranchChanged,
          ),
          IssueListView(
            key: ValueKey('issues_$_issuesVersion'),
            loadPage: (page) => GiteeApi.getIssues(
              widget.owner,
              widget.repo,
              state: 'all',
              page: page,
              perPage: 20,
            ),
            onTap: (issue) async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IssueDetailPage(
                    owner: widget.owner,
                    repo: widget.repo,
                    number: issue.number,
                  ),
                ),
              );
              _refreshAfterReturn(2);
            },
          ),
          CommitListView(
            key: ValueKey('commits_$_branch'),
            loadPage: (page) => GiteeApi.getCommits(
              widget.owner,
              widget.repo,
              branch: _branch.isEmpty ? null : _branch,
              page: page,
              perPage: 20,
            ),
            onTap: (commit) async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CommitDetailPage(
                    owner: widget.owner,
                    repo: widget.repo,
                    sha: commit.sha,
                  ),
                ),
              );
              _refreshAfterReturn(3);
            },
          ),
          PullRequestListView(
            key: ValueKey('pull_requests_$_pullRequestsVersion'),
            loadPage: (page) => GiteeApi.getPullRequests(
              widget.owner,
              widget.repo,
              state: 'all',
              page: page,
              perPage: 20,
            ),
            onTap: (pr) async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PullRequestDetailPage(
                    owner: widget.owner,
                    repo: widget.repo,
                    number: pr.number,
                  ),
                ),
              );
              _refreshAfterReturn(4);
            },
          ),
          ReleaseListView(
            loadPage: (page) => GiteeApi.getReleases(
              widget.owner,
              widget.repo,
              page: page,
              perPage: 20,
            ),
            onTap: (release) async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReleaseDetailPage(
                    release: release,
                    owner: widget.owner,
                    repo: widget.repo,
                  ),
                ),
              );
              _refreshAfterReturn(5);
            },
          ),
        ],
      ),
      floatingActionButton: _tabCtrl.index == 2 || _tabCtrl.index == 4
          ? FloatingActionButton(
              tooltip: _tabCtrl.index == 2 ? '创建 Issue' : '创建 Pull Request',
              onPressed: _createForCurrentTab,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }
}

/// 更多菜单中的统一图标文字行，控制窄屏菜单对齐。
class _RepoMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RepoMenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Repo repo;
  final String owner;
  final String repoName;
  final List<String> topics;
  final String? readme;
  final String branch;
  final bool readmeLoading;
  final String? readmeError;
  final VoidCallback onRetryReadme;

  const _OverviewTab({
    required this.repo,
    required this.owner,
    required this.repoName,
    required this.topics,
    required this.readme,
    required this.branch,
    required this.readmeLoading,
    required this.readmeError,
    required this.onRetryReadme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        GlassSurface(
          padding: const EdgeInsets.all(16),
          child: Padding(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Hero(
                      tag: 'repo-avatar-${repo.fullName}',
                      child: AppAvatar(
                          url: repo.ownerAvatar, size: 48, radius: 10),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            repo.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge,
                          ),
                          if (repo.language.isNotEmpty && repo.language != '未知')
                            Text(
                              repo.language,
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    if (repo.isPrivate)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.closed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '私有',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.closed,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(repo.description, style: theme.textTheme.bodyMedium),
                if (topics.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final topic in topics) _TopicChip(label: topic),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StatBadge(
                      icon: Icons.star,
                      value: repo.stars,
                      color: AppColors.starColor,
                    ),
                    const SizedBox(width: 20),
                    _StatBadge(
                      icon: Icons.call_split,
                      value: repo.forks,
                      color: context.secondaryForeground,
                    ),
                    const SizedBox(width: 20),
                    _StatBadge(
                      icon: Icons.visibility_outlined,
                      value: repo.watchers,
                      color: context.secondaryForeground,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RepoSubscribersPage(
                            owner: owner,
                            repo: repoName,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 8),
                if (repo.language.isNotEmpty && repo.language != '未知')
                  _InfoRow(
                    icon: Icons.circle,
                    iconColor: AppColors.languageColor(repo.language),
                    text: '主要语言：${repo.language}',
                  ),
                if (repo.defaultBranch.isNotEmpty)
                  _InfoRow(
                    icon: Icons.alt_route,
                    text: '默认分支：${repo.defaultBranch}',
                  ),
                if (repo.createdAt.isNotEmpty)
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    text: '创建于 ${formatDate(repo.createdAt)}',
                  ),
                if (repo.updatedAt.isNotEmpty)
                  _InfoRow(
                    icon: Icons.update,
                    text: '更新于 ${formatRelativeTime(repo.updatedAt)}',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassSurface(
          padding: const EdgeInsets.all(16),
          child: Padding(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('README', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    if (branch.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          branch,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (readmeLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (readmeError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: onRetryReadme,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('README 暂不可用，点击重试'),
                      ),
                    ),
                  )
                else if (readme == null || readme!.trim().isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        '暂无 README',
                        style: TextStyle(color: context.mutedForeground),
                      ),
                    ),
                  )
                else
                  AppMarkdown(
                    data: readme!,
                    owner: owner,
                    repo: repoName,
                    branch: branch,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 仓库 Topic 标签的小胶囊，样式与页内分支/私有徽章保持一致。
class _TopicChip extends StatelessWidget {
  final String label;

  const _TopicChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.primaryRed),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;
  final VoidCallback? onTap;

  const _StatBadge({
    required this.icon,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 5),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
    if (onTap == null) return badge;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: badge,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;

  const _InfoRow({required this.icon, required this.text, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor ?? context.mutedForeground),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _FilesTab extends StatefulWidget {
  final String owner;
  final String repo;
  final String branch;
  final List<String> branches;
  final ValueChanged<String> onBranchChanged;

  const _FilesTab({
    super.key,
    required this.owner,
    required this.repo,
    required this.branch,
    required this.branches,
    required this.onBranchChanged,
  });

  @override
  State<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<_FilesTab> {
  List<RepoFile> _files = [];
  bool _loading = true;
  int _generation = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _FilesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branch != widget.branch) _load();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files = await GiteeApi.getRepoContents(
        widget.owner,
        widget.repo,
        branch: widget.branch.isEmpty ? null : widget.branch,
      );
      files.sort((a, b) {
        if (a.type == b.type) return a.name.compareTo(b.name);
        return a.type == 'dir' ? -1 : 1;
      });
      if (!mounted || generation != _generation) return;
      setState(() {
        _files = files;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  void _openFile(RepoFile file) {
    if (file.type == 'dir') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RepoFileBrowserPage(
            owner: widget.owner,
            repo: widget.repo,
            initialPath: file.path,
            title: file.name,
            initialBranch: widget.branch.isEmpty ? null : widget.branch,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CodeViewPage(
            owner: widget.owner,
            repo: widget.repo,
            path: file.path,
            fileName: file.name,
            branch: widget.branch.isEmpty ? null : widget.branch,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        BranchSelector(
          branches: widget.branches,
          branch: widget.branch,
          onChanged: widget.onBranchChanged,
        ),
        Expanded(child: _buildBody(theme)),
      ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_files.isEmpty && _loading) return const SkeletonList();
    if (_files.isEmpty && _error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_files.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_off_outlined,
        title: '空仓库',
        subtitle: '当前分支下还没有内容',
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryRed,
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Icon(
                file.type == 'dir' ? Icons.folder : Icons.insert_drive_file,
                color: file.type == 'dir'
                    ? AppColors.folderIcon
                    : context.secondaryForeground,
                size: 28,
              ),
              title: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              subtitle: file.type == 'file' && file.size != null
                  ? Text(_formatSize(file.size!))
                  : null,
              trailing: Icon(
                Icons.chevron_right,
                color: context.mutedForeground,
              ),
              onTap: () => _openFile(file),
            ),
          );
        },
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }
}
