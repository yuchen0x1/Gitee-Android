import 'dart:async';

import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../api/so_search_api.dart';
import '../models/issue.dart';
import '../models/repo.dart';
import '../models/user.dart';
import '../providers/app_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/repo_card.dart';
import '../widgets/glass_surface.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_views.dart';
import '../widgets/time_format.dart';
import '../widgets/user_tile.dart';
import '../utils/launch_url.dart';
import '../utils/error_message.dart';
import 'issue_detail_page.dart';

enum _SearchType { repo, user, issue }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _hotTags = [
    'Flutter',
    'Vue',
    'Python',
    'Java',
    'Go',
    'React',
    '小程序',
    'Spring Boot',
    'Kotlin',
    'Swift'
  ];

  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _repoResults = <Repo>[];
  final _userResults = <User>[];
  final _issueResults = <Issue>[];
  _SearchType _type = _SearchType.repo;
  bool _loading = false, _searched = false, _hasMore = true;
  int _page = 1;
  int _searchGeneration = 0;
  String _lastQuery = '';
  String _issueState = '';
  String _issueRepo = '';
  String _issueLabel = '';
  String _userSort = '';
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  /// 输入防抖：停顿 400ms 后自动搜索；回车/点标签仍即时触发。
  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty || q == _lastQuery) return;
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(recordHistory: false);
    });
  }

  Future<void> _search({
    bool loadMore = false,
    bool recordHistory = true,
  }) async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    final generation = ++_searchGeneration;
    if (!loadMore) {
      _page = 1;
      _hasMore = true;
      _repoResults.clear();
      _userResults.clear();
      _issueResults.clear();
      _lastQuery = q;
      _searched = true;
      _error = null;
      if (recordHistory && mounted) {
        AppSettingsScope.of(context).addSearchHistory(q);
      }
    } else if (_loading) {
      return;
    }
    if (!_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = _page;
      if (_type == _SearchType.repo) {
        // v5 搜索接口存在服务端已知问题（常返回空结果），仓库搜索走
        // Gitee 网页搜索同款数据源。
        final list = await SoSearchApi.shared.searchRepos(
          _lastQuery,
          from: (page - 1) * 30,
          size: 30,
        );
        if (!mounted || generation != _searchGeneration) return;
        setState(() {
          _repoResults.addAll(list);
          _finishPage(list.length);
        });
      } else if (_type == _SearchType.user) {
        final list = await GiteeApi.searchUsers(
          _lastQuery,
          page: page,
          perPage: 30,
          sort: _userSort.isEmpty ? null : _userSort,
        );
        if (!mounted || generation != _searchGeneration) return;
        setState(() {
          _userResults.addAll(list);
          _finishPage(list.length);
        });
      } else {
        final list = await GiteeApi.searchIssues(
          _lastQuery,
          page: page,
          perPage: 30,
          repo: _issueRepo.isEmpty ? null : _issueRepo,
          label: _issueLabel.isEmpty ? null : _issueLabel,
          state: _issueState.isEmpty ? null : _issueState,
        );
        if (!mounted || generation != _searchGeneration) return;
        setState(() {
          _issueResults.addAll(list);
          _finishPage(list.length);
        });
      }
    } catch (e) {
      if (mounted && generation == _searchGeneration) {
        setState(() {
          _loading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  void _finishPage(int count) {
    _loading = false;
    _error = null;
    if (count < 30) _hasMore = false;
    _page++;
  }

  void _switchType(_SearchType type) {
    if (_type == type) return;
    setState(() => _type = type);
    if (_searched) _search();
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 160) {
      if (!_loading && _hasMore && _searched) _search(loadMore: true);
    }
  }

  void _reset() {
    setState(() {
      _ctrl.clear();
      _searched = false;
      _error = null;
      _page = 1;
      _hasMore = true;
      _repoResults.clear();
      _userResults.clear();
      _issueResults.clear();
    });
  }

  Future<void> _openFilters() async {
    var issueState = _issueState,
        issueRepo = _issueRepo,
        issueLabel = _issueLabel,
        userSort = _userSort;
    final issueRepoCtrl = TextEditingController(text: _issueRepo);
    final issueLabelCtrl = TextEditingController(text: _issueLabel);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, modalSetState) {
        final isIssue = _type == _SearchType.issue;
        return SafeArea(
            child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('搜索筛选', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close))
                ]),
                if (isIssue) ...[
                  TextField(
                      decoration:
                          const InputDecoration(labelText: '仓库（owner/name）'),
                      controller: issueRepoCtrl,
                      onChanged: (v) => issueRepo = v),
                  TextField(
                      decoration: const InputDecoration(labelText: '标签'),
                      controller: issueLabelCtrl,
                      onChanged: (v) => issueLabel = v),
                  DropdownButtonFormField<String>(
                      initialValue: issueState,
                      decoration: const InputDecoration(labelText: '状态'),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('全部状态')),
                        DropdownMenuItem(value: 'open', child: Text('开启')),
                        DropdownMenuItem(value: 'closed', child: Text('已关闭')),
                        DropdownMenuItem(value: 'rejected', child: Text('已拒绝'))
                      ],
                      onChanged: (v) =>
                          modalSetState(() => issueState = v ?? '')),
                ],
                if (!isIssue)
                  DropdownButtonFormField<String>(
                      initialValue: userSort,
                      decoration: const InputDecoration(labelText: '用户排序'),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('最佳匹配')),
                        DropdownMenuItem(
                            value: 'joined_at', child: Text('注册时间'))
                      ],
                      onChanged: (v) =>
                          modalSetState(() => userSort = v ?? '')),
                const SizedBox(height: 12),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('应用筛选'),
                        onPressed: () {
                          _issueState = issueState;
                          _issueRepo = issueRepo;
                          _issueLabel = issueLabel;
                          _userSort = userSort;
                          Navigator.pop(context);
                          if (_searched) _search();
                        })),
              ]),
        ));
      }),
    );
    issueRepoCtrl.dispose();
    issueLabelCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        actions: [
          if (_searched && _type != _SearchType.repo)
            IconButton(
              tooltip: '筛选',
              icon: const Icon(Icons.tune),
              onPressed: _openFilters,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: GlassSurface(
              borderRadius: BorderRadius.circular(18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SearchBar(
                controller: _ctrl,
                hintText: '搜索仓库、用户或 Issue',
                leading: const Icon(Icons.search),
                backgroundColor:
                    const WidgetStatePropertyAll(Colors.transparent),
                elevation: const WidgetStatePropertyAll(0),
                onChanged: _onQueryChanged,
                trailing: [
                  if (_ctrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _reset,
                    ),
                ],
                onSubmitted: (_) => _search(),
              ),
            ),
          ),
          if (_searched)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(4),
                  child: SegmentedButton<_SearchType>(
                    segments: const [
                      ButtonSegment(
                        value: _SearchType.repo,
                        label: Text('仓库'),
                        icon: Icon(Icons.folder_outlined),
                      ),
                      ButtonSegment(
                        value: _SearchType.user,
                        label: Text('用户'),
                        icon: Icon(Icons.person_outline),
                      ),
                      ButtonSegment(
                        value: _SearchType.issue,
                        label: Text('Issue'),
                        icon: Icon(Icons.bug_report_outlined),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (value) => _switchType(value.first),
                  ),
                ),
              ),
            ),
          if (_searched && _hasActiveFilter)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _filterSummary,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _searched ? _buildResults() : _buildDiscover(settings),
          ),
        ],
      ),
    );
  }

  bool get _hasActiveFilter =>
      _issueState.isNotEmpty ||
      _issueRepo.isNotEmpty ||
      _issueLabel.isNotEmpty ||
      _userSort.isNotEmpty;
  String get _filterSummary {
    final parts = <String>[];
    if (_issueRepo.isNotEmpty) parts.add(_issueRepo);
    if (_issueLabel.isNotEmpty) parts.add('标签: $_issueLabel');
    if (_issueState.isNotEmpty) parts.add(_issueState == 'open' ? '开启' : '已关闭');
    if (_userSort.isNotEmpty) parts.add('已排序');
    return '筛选：${parts.join(' · ')}';
  }

  Widget _buildResults() {
    final items = _type == _SearchType.repo
        ? _repoResults.length
        : _type == _SearchType.user
            ? _userResults.length
            : _issueResults.length;
    if (items == 0 && _loading) return const SkeletonList(variant: SkeletonVariant.repoCard);
    if (items == 0 && _error != null) {
      return ErrorState(message: _error!, onRetry: () => _search());
    }
    if (items == 0) {
      return EmptyState(
        icon: Icons.search_off,
        title: '没有找到相关内容',
        subtitle: 'Gitee 官方搜索接口当前不稳定，部分关键词可能返回空结果。\n'
            '可尝试在 Gitee 网页搜索「$_lastQuery」。',
        actionLabel: '在 Gitee 网页搜索',
        actionIcon: Icons.open_in_browser_rounded,
        onAction: () => launchExternalUrl(
          'https://so.gitee.com/?q=${Uri.encodeComponent(_lastQuery)}',
        ),
      );
    }
    return RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: () => _search(),
        child: ListView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items + 1,
            itemBuilder: (context, index) {
              if (index >= items) {
                return ListFooter(loading: _loading, hasMore: _hasMore);
              }
              if (_type == _SearchType.repo) {
                return RepoCard(repo: _repoResults[index]);
              }
              if (_type == _SearchType.user) {
                return UserTile(user: _userResults[index]);
              }
              return _IssueSearchTile(issue: _issueResults[index]);
            }));
  }

  Widget _buildDiscover(AppSettingsProvider settings) {
    final theme = Theme.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('热门搜索', style: theme.textTheme.titleMedium),
      const SizedBox(height: 12),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _hotTags
              .map((tag) => ActionChip(
                  label: Text(tag),
                  avatar: const Icon(Icons.local_fire_department,
                      size: 16, color: AppColors.primaryRed),
                  onPressed: () {
                    _ctrl.text = tag;
                    _search();
                  }))
              .toList()),
      if (settings.searchHistory.isNotEmpty) ...[
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: Text('搜索历史', style: theme.textTheme.titleMedium)),
          TextButton.icon(
              onPressed: settings.clearSearchHistory,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('清空'))
        ]),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: settings.searchHistory
                .map((keyword) => InputChip(
                    label: Text(keyword),
                    onPressed: () {
                      _ctrl.text = keyword;
                      _search();
                    },
                    onDeleted: () => settings.removeSearchHistory(keyword),
                    deleteIcon: const Icon(Icons.close, size: 16)))
                .toList())
      ]
    ]);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }
}

class _IssueSearchTile extends StatelessWidget {
  final Issue issue;
  const _IssueSearchTile({required this.issue});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canOpen =
        issue.repositoryOwner.isNotEmpty && issue.repositoryName.isNotEmpty;
    return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading:
                Icon(issue.state == 'open' ? Icons.radio_button_checked : Icons.check_circle_outline,
                    color: issue.state == 'open'
                        ? AppColors.success
                        : context.mutedForeground),
            title: Text(issue.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium),
            subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    '${issue.repositoryFullName.isEmpty ? 'Issue' : issue.repositoryFullName}  ·  #${issue.number}  ·  ${formatRelativeTime(issue.updatedAt)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis)),
            trailing: canOpen ? const Icon(Icons.chevron_right) : null,
            onTap: canOpen
                ? () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => IssueDetailPage(
                        owner: issue.repositoryOwner,
                        repo: issue.repositoryName,
                        number: issue.number)))
                : null));
  }
}
