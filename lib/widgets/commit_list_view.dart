import 'package:flutter/material.dart';
import '../models/commit.dart';
import '../theme/app_theme.dart';
import 'app_image.dart';
import 'paged_list_view.dart';
import 'time_format.dart';

/// 暂无提交记录分页列表，点击通过回调进入详情页。
class CommitListView extends StatelessWidget {
  final Future<List<Commit>> Function(int page) loadPage;
  final void Function(Commit item) onTap;

  const CommitListView({
    super.key,
    required this.loadPage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PagedListView<Commit>(
      loadPage: loadPage,
      itemBuilder: (context, item) => _CommitCard(
        commit: item,
        onTap: () => onTap(item),
      ),
      emptyIcon: Icons.history,
      emptyTitle: '暂无提交记录',
      emptySubtitle: '该分支还没有提交记录',
    );
  }
}

class _CommitCard extends StatelessWidget {
  final Commit commit;
  final VoidCallback onTap;

  const _CommitCard({required this.commit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sha = commit.sha.length > 7 ? commit.sha.substring(0, 7) : commit.sha;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                commit.message.split('\n').first,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (commit.author != null) ...[
                    AppAvatar(
                        url: commit.author!.avatarUrl, size: 22, radius: 6),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      commit.authorLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(sha, style: theme.textTheme.bodySmall),
                  const SizedBox(width: 12),
                  Text(formatRelativeTime(commit.date),
                      style: theme.textTheme.bodySmall),
                ],
              ),
              if (commit.totalChanges > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.add_circle_outline,
                        size: 14, color: AppColors.success),
                    const SizedBox(width: 3),
                    Text('+${commit.additions}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.success)),
                    const SizedBox(width: 12),
                    const Icon(Icons.remove_circle_outline,
                        size: 14, color: AppColors.primaryRed),
                    const SizedBox(width: 3),
                    Text('${commit.deletions}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.primaryRed)),
                    const SizedBox(width: 12),
                    Text('共 ${commit.totalChanges} 处变更',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
