import 'dart:async';

import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../models/commit.dart';
import '../models/gitee_api_entities.dart';
import '../models/issue.dart';
import '../models/pull_request.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';
import '../widgets/app_markdown.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_views.dart';
import '../widgets/time_format.dart';
import 'issue_detail_page.dart';

/// Pull Request 详情页：分支关系、状态、正文与关联提交。
class PullRequestDetailPage extends StatefulWidget {
  final String owner;
  final String repo;
  final int number;

  const PullRequestDetailPage({
    super.key,
    required this.owner,
    required this.repo,
    required this.number,
  });

  @override
  State<PullRequestDetailPage> createState() => _PullRequestDetailPageState();
}

class _PullRequestDetailPageState extends State<PullRequestDetailPage> {
  final List<Commit> _commits = [];
  final List<PullRequestComment> _comments = [];
  final List<PullRequestFile> _files = [];
  final ScrollController _scroll = ScrollController();
  final TextEditingController _commentCtrl = TextEditingController();
  PullRequest? _pr;
  bool _loading = true;
  bool _commitsLoading = false;
  bool _commentSubmitting = false;
  bool _actionInFlight = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  List<Issue> _relatedIssues = [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _commits.clear();
    }
    if (_pr == null) setState(() => _loading = true);
    try {
      final pr = await GiteeApi.getPullRequestDetail(
        widget.owner,
        widget.repo,
        widget.number,
      );
      final results = await Future.wait<dynamic>([
        GiteeApi.getPullRequestCommits(
          widget.owner,
          widget.repo,
          widget.number,
          page: _page,
          perPage: 20,
        ),
        GiteeApi.getPullRequestComments(
          widget.owner,
          widget.repo,
          widget.number,
        ),
        GiteeApi.getPullRequestFiles(widget.owner, widget.repo, widget.number),
      ]);
      final commits = results[0] as List<Commit>;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _pr = pr;
        _comments
          ..clear()
          ..addAll(results[1] as List<PullRequestComment>);
        _files
          ..clear()
          ..addAll(results[2] as List<PullRequestFile>);
        _commitsLoading = false;
        _commits.addAll(commits);
        if (commits.length < 20) _hasMore = false;
        _page++;
      });
      unawaited(_loadRelatedIssues());
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  /// 关联 Issue 属于增强信息，失败时不展示，不影响主体内容。
  Future<void> _loadRelatedIssues() async {
    try {
      final issues = await GiteeApi.getPullRequestIssues(
        widget.owner,
        widget.repo,
        widget.number,
      );
      if (!mounted || issues.isEmpty) return;
      setState(() => _relatedIssues = issues);
    } catch (_) {
      // 关联 Issue 接口异常时保持空列表。
    }
  }

  Future<void> _submitComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty || _commentSubmitting) return;
    setState(() => _commentSubmitting = true);
    try {
      final comment = await GiteeApi.createPullRequestComment(
        owner: widget.owner,
        repo: widget.repo,
        number: widget.number,
        body: body,
      );
      if (!mounted) return;
      setState(() {
        _comments.insert(0, comment);
        _commentCtrl.clear();
        _commentSubmitting = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _commentSubmitting = false);
        _showMessage(e.toString());
      }
    }
  }

  Future<void> _changeState(String state) async {
    if (_actionInFlight || _pr == null) return;
    setState(() => _actionInFlight = true);
    try {
      final updated = state == 'open'
          ? await GiteeApi.reopenPullRequest(
              widget.owner,
              widget.repo,
              widget.number,
            )
          : await GiteeApi.closePullRequest(
              widget.owner,
              widget.repo,
              widget.number,
            );
      if (mounted) {
        setState(() {
          _pr = updated;
          _actionInFlight = false;
        });
        _showMessage(state == 'open' ? 'PR 已重开' : 'PR 已关闭');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionInFlight = false);
        _showMessage(e.toString());
      }
    }
  }

  Future<void> _merge() async {
    if (_actionInFlight || _pr == null || _pr!.state != 'open') return;
    setState(() => _actionInFlight = true);
    try {
      await GiteeApi.mergePullRequest(
        owner: widget.owner,
        repo: widget.repo,
        number: widget.number,
        mergeMethod: 'merge',
      );
      if (mounted) {
        setState(() => _actionInFlight = false);
        await _load(refresh: true);
        _showMessage('PR 合并请求已提交');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionInFlight = false);
        _showMessage(e.toString());
      }
    }
  }

  Future<void> _review() async {
    try {
      await GiteeApi.processPullRequestReview(
        owner: widget.owner,
        repo: widget.repo,
        number: widget.number,
      );
      if (mounted) _showMessage('审核请求已提交');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _test() async {
    try {
      await GiteeApi.testPullRequest(
        owner: widget.owner,
        repo: widget.repo,
        number: widget.number,
      );
      if (mounted) _showMessage('测试请求已提交');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _deleteComment(PullRequestComment comment) async {
    try {
      await GiteeApi.deletePullRequestComment(
        owner: widget.owner,
        repo: widget.repo,
        commentId: comment.id,
      );
      if (mounted) setState(() => _comments.remove(comment));
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _editComment(PullRequestComment comment) async {
    final controller = TextEditingController(text: comment.body);
    final body = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑评论'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(hintText: '请输入评论内容'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || body == null || body.isEmpty || body == comment.body) {
      return;
    }
    try {
      final updated = await GiteeApi.updatePullRequestComment(
        owner: widget.owner,
        repo: widget.repo,
        commentId: comment.id,
        body: body,
      );
      if (mounted) {
        final index = _comments.indexWhere((item) => item.id == comment.id);
        if (index >= 0) setState(() => _comments[index] = updated);
      }
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString());
      }
    }
  }

  void _showFile(PullRequestFile file) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Text(file.filename, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text('${file.status}  +${file.additions}  -${file.deletions}'),
            const SizedBox(height: 12),
            SelectableText(file.patch.isEmpty ? '暂无 diff 数据' : file.patch),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadMore() async {
    if (_commitsLoading || !_hasMore) return;
    setState(() => _commitsLoading = true);
    try {
      final commits = await GiteeApi.getPullRequestCommits(
        widget.owner,
        widget.repo,
        widget.number,
        page: _page,
        perPage: 20,
      );
      if (!mounted) return;
      setState(() {
        _commitsLoading = false;
        _commits.addAll(commits);
        if (commits.length < 20) _hasMore = false;
        _page++;
      });
    } catch (_) {
      if (mounted) setState(() => _commitsLoading = false);
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 100) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pr == null && _loading) return const Scaffold(body: SkeletonList());
    if (_pr == null && _error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('#${widget.number}')),
        body: ErrorState(message: _error!, onRetry: () => _load(refresh: true)),
      );
    }
    final pr = _pr!;
    return Scaffold(
      appBar: AppBar(
        title: Text('#${widget.number}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'open':
                case 'closed':
                  _changeState(value);
                  break;
                case 'merge':
                  _merge();
                  break;
                case 'review':
                  _review();
                  break;
                case 'test':
                  _test();
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'open',
                enabled: pr.state != 'open',
                child: const Text('重开 PR'),
              ),
              PopupMenuItem(
                value: 'closed',
                enabled: pr.state == 'open',
                child: const Text('关闭 PR'),
              ),
              PopupMenuItem(
                value: 'merge',
                enabled: pr.state == 'open',
                child: const Text('合并 PR'),
              ),
              const PopupMenuItem(value: 'review', child: Text('提交审核')),
              const PopupMenuItem(value: 'test', child: Text('运行测试')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: () => _load(refresh: true),
        child: ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: 5 + _comments.length + _files.length + _commits.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _PullRequestHeader(pr: pr);
            if (index == 1) {
              return Column(
                children: [
                  if (_relatedIssues.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('关联 Issue (${_relatedIssues.length})',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            ..._relatedIssues.map(
                              (issue) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  issue.state == 'open'
                                      ? Icons.bug_report_outlined
                                      : Icons.check_circle_outline,
                                  size: 20,
                                  color: issue.state == 'open'
                                      ? AppColors.primaryRed
                                      : AppColors.success,
                                ),
                                title: Text(
                                  issue.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                                subtitle: Text('Issue #${issue.number} · ${issue.state}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                trailing:
                                    const Icon(Icons.chevron_right, size: 18),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => IssueDetailPage(
                                        owner: widget.owner,
                                        repo: widget.repo,
                                        number: issue.number,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              );
            }
            if (index == 2) {
              return Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: Text(
                  '评论 (${_comments.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            }
            final commentIndex = index - 3;
            if (commentIndex < _comments.length) {
              final comment = _comments[commentIndex];
              return _PullRequestCommentCard(
                comment: comment,
                onDelete: () => _deleteComment(comment),
                onEdit: () => _editComment(comment),
              );
            }
            final filesTitleIndex = 3 + _comments.length;
            if (index == filesTitleIndex) {
              return Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: Text(
                  '文件变更 (${_files.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            }
            final fileIndex = index - filesTitleIndex - 1;
            if (fileIndex >= 0 && fileIndex < _files.length) {
              final file = _files[fileIndex];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(file.filename),
                  subtitle: Text(
                    '${file.status}  +${file.additions}  -${file.deletions}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showFile(file),
                ),
              );
            }
            final commitsTitleIndex = filesTitleIndex + 1 + _files.length;
            if (index == commitsTitleIndex) {
              return Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: Text(
                  '关联提交 (${_commits.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            }
            final commitIndex = index - commitsTitleIndex - 1;
            if (commitIndex >= _commits.length) {
              return ListFooter(loading: _commitsLoading, hasMore: _hasMore);
            }
            return _CommitTile(commit: _commits[commitIndex]);
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '发表评论',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: '发送评论',
                onPressed: _commentSubmitting ? null : _submitComment,
                icon: _commentSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }
}

class _PullRequestCommentCard extends StatelessWidget {
  final PullRequestComment comment;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _PullRequestCommentCard(
      {required this.comment, this.onDelete, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                  url: comment.user?.avatarUrl ?? '',
                  size: 28,
                  radius: 7,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(comment.user?.login ?? '匿名用户')),
                Text(
                  formatRelativeTime(comment.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (onDelete != null || onEdit != null)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'delete') onDelete?.call();
                      if (value == 'edit') onEdit?.call();
                    },
                    itemBuilder: (_) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('编辑评论'),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('删除评论'),
                        ),
                    ],
                  ),
              ],
            ),
            if (comment.path.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  comment.path,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (comment.body.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              AppMarkdown(data: comment.body),
            ],
          ],
        ),
      ),
    );
  }
}

class _PullRequestHeader extends StatelessWidget {
  final PullRequest pr;

  const _PullRequestHeader({required this.pr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (pr.state) {
      'merged' => ('已合并', const Color(0xFF8B5CF6)),
      'open' => ('开放', AppColors.success),
      _ => ('已关闭', AppColors.closed),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '更新于 ${formatRelativeTime(pr.updatedAt)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(pr.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                AppAvatar(url: pr.user?.avatarUrl ?? '', size: 28, radius: 8),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pr.user?.login ?? '匿名用户',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        '创建于 ${formatDate(pr.createdAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.call_split,
                    size: 18,
                    color: AppColors.primaryRed,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${pr.headBranch} → ${pr.baseBranch}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (pr.body.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 6),
              AppMarkdown(data: pr.body),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommitTile extends StatelessWidget {
  final Commit commit;

  const _CommitTile({required this.commit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sha = commit.sha.length > 7 ? commit.sha.substring(0, 7) : commit.sha;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(url: commit.author?.avatarUrl ?? '', size: 32, radius: 8),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    commit.message.split('\n').first,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(sha, style: theme.textTheme.bodySmall),
                      const SizedBox(width: 10),
                      Text(
                        commit.author?.login ?? '未知作者',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        formatRelativeTime(commit.date),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
