import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../models/commit.dart';
import '../theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final commit =
          await GiteeApi.getCommitDetail(widget.owner, widget.repo, widget.sha);
      if (!mounted) return;
      setState(() {
        _commit = commit;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
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
                        color: theme.brightness == Brightness.dark
                            ? const Color(0xFF1E1E2E)
                            : const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        file.patch ?? '暂无 diff 数据',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.5,
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFFE4E4EF)
                              : AppColors.textPrimary,
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
