import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/error_message.dart';
import '../ai/ai_summary.dart';
import '../api/gitee_api.dart';
import '../models/issue.dart';
import '../models/gitee_api_entities.dart' show Milestone;
import '../models/issue_comment.dart';
import '../models/pull_request.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';
import '../widgets/app_markdown.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_views.dart';
import '../widgets/time_format.dart';
import 'pr_detail_page.dart';

/// Issue 详情页：标题、状态、正文 Markdown 与评论列表。
class IssueDetailPage extends StatefulWidget {
  final String owner;
  final String repo;
  final String number;

  const IssueDetailPage({
    super.key,
    required this.owner,
    required this.repo,
    required this.number,
  });

  @override
  State<IssueDetailPage> createState() => _IssueDetailPageState();
}

class _IssueDetailPageState extends State<IssueDetailPage> {
  final List<IssueComment> _comments = [];
  final ScrollController _scroll = ScrollController();
  final TextEditingController _commentCtrl = TextEditingController();
  Issue? _issue;
  bool _loading = true;
  bool _commentsLoading = false;
  bool _commentSubmitting = false;
  bool _actionInFlight = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  List<PullRequest> _relatedPRs = [];

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
      _comments.clear();
    }
    if (_issue == null) setState(() => _loading = true);
    try {
      final issue = await GiteeApi.getIssueDetail(
        widget.owner,
        widget.repo,
        widget.number,
      );
      final comments = await GiteeApi.getIssueComments(
        widget.owner,
        widget.repo,
        widget.number,
        page: _page,
        perPage: 20,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _issue = issue;
        _commentsLoading = false;
        _comments.addAll(comments);
        if (comments.length < 20) _hasMore = false;
        _page++;
      });
      unawaited(_loadRelatedPRs());
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_commentsLoading || !_hasMore) return;
    setState(() => _commentsLoading = true);
    try {
      final comments = await GiteeApi.getIssueComments(
        widget.owner,
        widget.repo,
        widget.number,
        page: _page,
        perPage: 20,
      );
      if (!mounted) return;
      setState(() {
        _commentsLoading = false;
        _comments.addAll(comments);
        if (comments.length < 20) _hasMore = false;
        _page++;
      });
    } catch (_) {
      if (mounted) setState(() => _commentsLoading = false);
    }
  }

  /// 关联 PR 属于增强信息，失败时不展示，不影响主体内容。
  Future<void> _loadRelatedPRs() async {
    try {
      final prs = await GiteeApi.getIssuePullRequests(
        widget.owner,
        widget.number,
        repo: widget.repo,
      );
      if (!mounted || prs.isEmpty) return;
      setState(() => _relatedPRs = prs);
    } catch (_) {
      // 关联 PR 接口异常时保持空列表。
    }
  }

  Future<void> _submitComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty || _commentSubmitting) return;
    setState(() => _commentSubmitting = true);
    try {
      final comment = await GiteeApi.createIssueComment(
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

  Future<void> _aiSummarize() async {
    final issue = _issue;
    if (issue == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final commentsText = _comments
        .take(10)
        .map((c) => '${c.user?.login ?? ""}：${c.body}')
        .join('\n');
    final text =
        '${issue.title}\n\n${issue.state == "open" ? "状态：开放" : "状态：已关闭"}'
        '\n\n${commentsText.isEmpty ? "暂无评论" : commentsText}';
    final summary = await AiSummary.summarize(text, title: issue.title);
    if (!mounted) return;
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 摘要'),
        content: SelectableText(summary),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  Future<void> _editLabels() async {
    final issue = _issue;
    if (issue == null || _actionInFlight) return;
    List<Label> repoLabels;
    try {
      repoLabels = await GiteeApi.getRepoLabels(widget.owner, widget.repo);
    } catch (e) {
      _showMessage(e.toString());
      return;
    }
    if (!mounted) return;
    if (repoLabels.isEmpty) {
      _showMessage('仓库还没有标签，可在仓库能力中心创建');
      return;
    }
    final selected = issue.labels.map((l) => l.name).toSet();
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) {
        var draft = Set<String>.from(selected);
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('设置标签'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: repoLabels
                    .map(
                      (label) => CheckboxListTile(
                        dense: true,
                        title: Text(label.name),
                        value: draft.contains(label.name),
                        onChanged: (checked) => setDialogState(() {
                          checked == true
                              ? draft.add(label.name)
                              : draft.remove(label.name);
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, draft),
                child: const Text('保存'),
              ),
            ],
          ),
        );
      },
    );
    if (result == null) return;
    setState(() => _actionInFlight = true);
    try {
      await GiteeApi.setIssueLabels(
        owner: widget.owner,
        repo: widget.repo,
        number: widget.number,
        labels: result.toList(),
      );
      await _load(refresh: true);
      if (mounted) {
        setState(() => _actionInFlight = false);
        _showMessage('标签已更新');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionInFlight = false);
        _showMessage(e.toString());
      }
    }
  }

  Future<void> _editMilestone() async {
    final issue = _issue;
    if (issue == null || _actionInFlight) return;
    List<Milestone> milestones;
    try {
      milestones =
          await GiteeApi.getMilestones(widget.owner, widget.repo, state: 'all');
    } catch (e) {
      _showMessage(e.toString());
      return;
    }
    if (!mounted) return;
    if (milestones.isEmpty) {
      _showMessage('仓库还没有里程碑，可在仓库能力中心创建');
      return;
    }
    const clearValue = -1;
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('设置里程碑'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, clearValue),
            child: const Text('无里程碑'),
          ),
          for (final milestone in milestones)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, milestone.id),
              child: Row(
                children: [
                  Expanded(child: Text(milestone.title)),
                  Text(
                    milestone.state == 'open' ? '进行中' : '已关闭',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (result == null) return;
    setState(() => _actionInFlight = true);
    try {
      await GiteeApi.updateIssue(
        owner: widget.owner,
        repo: widget.repo,
        number: widget.number,
        milestone: result == clearValue ? 0 : result,
      );
      await _load(refresh: true);
      if (mounted) {
        setState(() => _actionInFlight = false);
        _showMessage('里程碑已更新');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionInFlight = false);
        _showMessage(e.toString());
      }
    }
  }

  Future<void> _changeState(String state) async {
    final issue = _issue;
    if (issue == null || _actionInFlight || issue.state == state) return;
    setState(() => _actionInFlight = true);
    try {
      final updated = await GiteeApi.updateIssue(
        owner: widget.owner,
        repo: widget.repo,
        number: widget.number,
        title: issue.title,
        body: issue.body,
        state: state,
      );
      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _issue = updated;
          _actionInFlight = false;
        });
        _showMessage(state == 'open' ? 'Issue 已重开' : 'Issue 已关闭');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionInFlight = false);
        _showMessage(e.toString());
      }
    }
  }

  Future<void> _deleteComment(IssueComment comment) async {
    try {
      await GiteeApi.deleteIssueComment(
        owner: widget.owner,
        repo: widget.repo,
        commentId: comment.id,
      );
      if (mounted) setState(() => _comments.remove(comment));
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  Future<void> _editComment(IssueComment comment) async {
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
      final updated = await GiteeApi.updateIssueComment(
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 100) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_issue == null && _loading) return const Scaffold(body: SkeletonList());
    if (_issue == null && _error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('#${widget.number}')),
        body: ErrorState(message: _error!, onRetry: () => _load(refresh: true)),
      );
    }
    final issue = _issue!;
    return Scaffold(
      appBar: AppBar(
        title: Text('#${widget.number}'),
        actions: [
          if (AiSummary.isConfigured)
            IconButton(
              icon: const Icon(Icons.smart_toy_outlined),
              tooltip: 'AI 摘要',
              onPressed: _aiSummarize,
            ),
          PopupMenuButton<String>(
            tooltip: '标签与里程碑',
            icon: const Icon(Icons.tune),
            onSelected: (value) {
              if (value == 'labels') _editLabels();
              if (value == 'milestone') _editMilestone();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'labels',
                child: Text('设置标签'),
              ),
              PopupMenuItem(
                value: 'milestone',
                child: Text('设置里程碑'),
              ),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: _changeState,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'open',
                enabled: issue.state != 'open',
                child: const Text('重开 Issue'),
              ),
              PopupMenuItem(
                value: 'closed',
                enabled: issue.state == 'open',
                child: const Text('关闭 Issue'),
              ),
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
          itemCount: 2 + _comments.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IssueHeader(issue: issue),
                  if (issue.labels.isNotEmpty || issue.milestoneTitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (issue.milestoneTitle.isNotEmpty)
                            InputChip(
                              avatar: const Icon(Icons.flag_outlined, size: 16),
                              label: Text(issue.milestoneTitle),
                              onPressed: _editMilestone,
                            ),
                          ...issue.labels.map(
                            (label) {
                              final cleanColor = label.color.replaceAll('#', '');
                              final parsedColor = int.tryParse('FF$cleanColor', radix: 16);
                              final color = (cleanColor.isEmpty || parsedColor == null)
                                  ? AppColors.primaryRed
                                  : Color(parsedColor);
                              return InputChip(
                                avatar: Icon(Icons.circle, size: 10, color: color),
                                label: Text(label.name),
                                onPressed: _editLabels,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  if (_relatedPRs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('关联 PR (${_relatedPRs.length})',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium),
                              const SizedBox(height: 4),
                              ..._relatedPRs.map(
                                (pr) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    pr.state == 'merged'
                                        ? Icons.merge_outlined
                                        : Icons.call_split_outlined,
                                    size: 20,
                                    color: pr.state == 'merged'
                                        ? AppColors.success
                                        : pr.state == 'closed'
                                            ? AppColors.closed
                                            : AppColors.primaryRed,
                                  ),
                                  title: Text(
                                    pr.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  subtitle: Text(
                                      'PR #${pr.number} · ${pr.state}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  trailing: const Icon(Icons.chevron_right,
                                      size: 18),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PullRequestDetailPage(
                                          owner: widget.owner,
                                          repo: widget.repo,
                                          number: pr.number,
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
                    ),
                ],
              );
            }
            if (index == 1) return _SectionTitle(count: issue.comments);
            final commentIndex = index - 2;
            if (commentIndex >= _comments.length) {
              return ListFooter(loading: _commentsLoading, hasMore: _hasMore);
            }
            return _CommentCard(
              comment: _comments[commentIndex],
              onDelete: () => _deleteComment(_comments[commentIndex]),
              onEdit: () => _editComment(_comments[commentIndex]),
            );
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

class _IssueHeader extends StatelessWidget {
  final Issue issue;

  const _IssueHeader({required this.issue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = issue.state == 'open';
    final color = open ? AppColors.success : AppColors.closed;
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        open ? Icons.check_circle_outline : Icons.cancel_outlined,
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        open ? '开放' : '已关闭',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '更新于 ${formatRelativeTime(issue.updatedAt)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(issue.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                AppAvatar(
                  url: issue.user?.avatarUrl ?? '',
                  size: 28,
                  radius: 8,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.user?.login ?? '匿名用户',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        '创建于 ${formatDate(issue.createdAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: context.mutedForeground,
                ),
                const SizedBox(width: 4),
                Text('${issue.comments}', style: theme.textTheme.bodySmall),
              ],
            ),
            if (issue.body.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 6),
              AppMarkdown(data: issue.body),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final int count;

  const _SectionTitle({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        '评论 ($count)',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final IssueComment comment;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _CommentCard({required this.comment, this.onDelete, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                  radius: 8,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    comment.user?.login ?? '匿名用户',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  formatRelativeTime(comment.createdAt),
                  style: theme.textTheme.bodySmall,
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
            if (comment.body.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              AppMarkdown(data: comment.body),
            ],
          ],
        ),
      ),
    );
  }
}
