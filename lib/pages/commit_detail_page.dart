import 'dart:async';

import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../models/check_run.dart';
import '../models/commit.dart';
import '../models/issue_comment.dart';
import '../theme/app_theme.dart';
import '../theme/code_theme.dart';
import '../utils/launch_url.dart';
import '../utils/error_message.dart';
import '../widgets/app_image.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_views.dart';
import '../widgets/time_format.dart';

/// Commit 详情页：提交信息、统计与文件变更列表。
class CommitDetailPage extends StatefulWidget {
  final String owner;
  final String repo;
  final String sha;

  const CommitDetailPage({
    super.key,
    required this.owner,
    required this.repo,
    required this.sha,
  });

  @override
  State<CommitDetailPage> createState() => _CommitDetailPageState();
}

class _CommitDetailPageState extends State<CommitDetailPage> {
  Commit? _commit;
  bool _loading = true;
  String? _error;
  final List<IssueComment> _comments = [];
  final TextEditingController _commentCtrl = TextEditingController();
  bool _commentsLoading = false;
  bool _commentSubmitting = false;
  List<CheckRun> _checkRuns = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _comments.clear();
      _checkRuns = [];
    });
    try {
      final commit =
          await GiteeApi.getCommitDetail(widget.owner, widget.repo, widget.sha);
      if (!mounted) return;
      setState(() {
        _commit = commit;
        _loading = false;
        _error = null;
      });
      _loadComments();
      unawaited(_loadCheckRuns());
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  /// CI 检查项属于增强信息，失败时不展示，不影响主体内容。
  Future<void> _loadCheckRuns() async {
    try {
      final runs = await GiteeApi.getCommitCheckRuns(
        widget.owner,
        widget.repo,
        widget.sha,
      );
      if (!mounted || runs.isEmpty) return;
      setState(() => _checkRuns = runs);
    } catch (_) {
      // 检查项接口异常时保持空列表（未开通 Gitee Go 等场景）。
    }
  }

  Future<void> _loadComments() async {
    if (_commentsLoading) return;
    setState(() => _commentsLoading = true);
    try {
      final comments = await GiteeApi.getCommitComments(
        widget.owner,
        widget.repo,
        widget.sha,
      );
      if (!mounted) return;
      setState(() {
        _comments.addAll(comments);
        _commentsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _commentsLoading = false);
    }
  }

  Future<void> _submitComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty || _commentSubmitting) return;
    setState(() => _commentSubmitting = true);
    try {
      final comment = await GiteeApi.createCommitComment(
        owner: widget.owner,
        repo: widget.repo,
        sha: widget.sha,
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deleteComment(IssueComment comment) async {
    try {
      await GiteeApi.deleteCommitComment(widget.owner, widget.repo, comment.id);
      if (mounted) setState(() => _comments.remove(comment));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showDiff(CommitFile file) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
        final theme = Theme.of(context);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          file.filename,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        _DiffStat(label: file.status, color: AppColors.closed),
                        _DiffStat(
                            label: '+${file.additions}',
                            color: AppColors.success),
                        _DiffStat(
                            label: '-${file.deletions}',
                            color: AppColors.primaryRed),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: CodeTheme.backgroundOf(theme.brightness),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        file.patch ?? '暂无 diff 数据',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.5,
                          color: CodeTheme.textOf(theme.brightness),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_commit == null && _loading) {
      return const Scaffold(body: SkeletonList());
    }
    if (_commit == null && _error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('提交详情')),
        body: ErrorState(message: _error!, onRetry: _load),
      );
    }
    final commit = _commit!;
    final sha = commit.sha.length > 7 ? commit.sha.substring(0, 7) : commit.sha;
    return Scaffold(
      appBar: AppBar(title: Text(sha)),
      body: RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(commit.message,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        AppAvatar(
                            url: commit.author?.avatarUrl ?? '',
                            size: 32,
                            radius: 8),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(commit.author?.login ?? '未知作者',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(formatDate(commit.date),
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _DiffStat(
                            label: '共 ${commit.totalChanges} 处变更',
                            color: AppColors.textSecondary),
                        const SizedBox(width: 12),
                        _DiffStat(
                            label: '+${commit.additions}',
                            color: AppColors.success),
                        const SizedBox(width: 12),
                        _DiffStat(
                            label: '-${commit.deletions}',
                            color: AppColors.primaryRed),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_checkRuns.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CI 检查 (${_checkRuns.length})',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      ..._checkRuns.map((run) {
                        final (icon, color) = run.isRunning
                            ? (Icons.pending_outlined, AppColors.starColor)
                            : run.isFailure
                                ? (Icons.error_outline, AppColors.primaryRed)
                                : (Icons.check_circle_outline,
                                    AppColors.success);
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(icon, color: color),
                          title: Text(
                            run.name.isEmpty ? '未命名检查' : run.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            run.isRunning
                                ? '进行中'
                                : run.conclusion.isEmpty
                                    ? '等待调度'
                                    : '结论：${run.conclusion}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: run.detailsUrl.isEmpty
                              ? null
                              : const Icon(Icons.open_in_new, size: 18),
                          onTap: run.detailsUrl.isEmpty
                              ? null
                              : () => launchExternalUrl(run.detailsUrl),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            if (_checkRuns.isNotEmpty) const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('评论 (${_comments.length})',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    if (_commentsLoading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (_comments.isEmpty)
                      Text('暂无评论',
                          style: Theme.of(context).textTheme.bodySmall)
                    else
                      ..._comments.map(
                        (comment) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppAvatar(
                                url: comment.user?.avatarUrl ?? '',
                                size: 28,
                                radius: 7,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          comment.user?.login ?? '匿名',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          formatRelativeTime(comment.createdAt),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          tooltip: '删除评论',
                                          icon: const Icon(
                                              Icons.delete_outline,
                                              size: 18),
                                          onPressed: () =>
                                              _deleteComment(comment),
                                        ),
                                      ],
                                    ),
                                    SelectableText(comment.body),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: '评论这次提交',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: '发送评论',
                          onPressed:
                              _commentSubmitting ? null : _submitComment,
                          icon: _commentSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.send, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 10),
              child: Text('文件变更 (${commit.files.length})',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            if (commit.files.isEmpty)
              const EmptyState(
                icon: Icons.folder_off_outlined,
                title: '暂无文件变更',
                subtitle: '该提交没有可展示的文件改动',
              )
            else
              ...commit.files.map((file) =>
                  _FileChangeTile(file: file, onTap: () => _showDiff(file))),
          ],
        ),
      ),
    );
  }
}

class _FileChangeTile extends StatelessWidget {
  final CommitFile file;
  final VoidCallback onTap;

  const _FileChangeTile({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          file.status == 'added'
              ? Icons.add_circle_outline
              : Icons.description_outlined,
          color: file.status == 'added'
              ? AppColors.success
              : AppColors.textSecondary,
        ),
        title: Text(file.filename,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text('+${file.additions}',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.success)),
              const SizedBox(width: 10),
              Text('${file.deletions}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.primaryRed)),
              const SizedBox(width: 10),
              Text(file.status, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        trailing:
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        onTap: onTap,
      ),
    );
  }
}

class _DiffStat extends StatelessWidget {
  final String label;
  final Color color;

  const _DiffStat({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
