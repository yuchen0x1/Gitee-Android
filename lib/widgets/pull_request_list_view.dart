import 'package:flutter/material.dart';
import '../models/pull_request.dart';
import '../theme/app_theme.dart';
import 'app_image.dart';
import 'paged_list_view.dart';
import 'time_format.dart';

/// 暂无 Pull Request分页列表，点击通过回调进入详情页。
class PullRequestListView extends StatelessWidget {
  final Future<List<PullRequest>> Function(int page) loadPage;
  final void Function(PullRequest item) onTap;

  const PullRequestListView({
    super.key,
    required this.loadPage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PagedListView<PullRequest>(
      loadPage: loadPage,
      itemBuilder: (context, item) => _PullRequestCard(
        pr: item,
        onTap: () => onTap(item),
      ),
      emptyIcon: Icons.merge_type,
      emptyTitle: '暂无 Pull Request',
      emptySubtitle: '仓库还没有提交过 Pull Request',
    );
  }
}

class _PullRequestCard extends StatelessWidget {
  final PullRequest pr;
  final VoidCallback onTap;

  const _PullRequestCard({required this.pr, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              Row(
                children: [
                  _StateChip(state: pr.state),
                  const SizedBox(width: 8),
                  Text('#${pr.number}', style: theme.textTheme.bodySmall),
                  const Spacer(),
                  Text(formatRelativeTime(pr.createdAt),
                      style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                pr.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (pr.user != null) ...[
                    AppAvatar(url: pr.user!.avatarUrl, size: 22, radius: 6),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      pr.user?.login ?? '匿名用户',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${pr.headBranch} → ${pr.baseBranch}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.primaryRed),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  final String state;

  const _StateChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      'merged' => ('已合并', AppColors.merged),
      'open' => ('开放', AppColors.success),
      _ => ('已关闭', AppColors.closed),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
