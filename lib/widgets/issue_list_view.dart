import 'package:flutter/material.dart';
import '../models/issue.dart';
import '../theme/app_theme.dart';
import 'app_image.dart';
import 'paged_list_view.dart';
import 'time_format.dart';

/// 暂无 Issue分页列表，点击通过回调进入详情页。
class IssueListView extends StatelessWidget {
  final Future<List<Issue>> Function(int page) loadPage;
  final void Function(Issue item) onTap;

  const IssueListView({
    super.key,
    required this.loadPage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PagedListView<Issue>(
      loadPage: loadPage,
      itemBuilder: (context, item) => _IssueCard(
        issue: item,
        onTap: () => onTap(item),
      ),
      emptyIcon: Icons.bug_report_outlined,
      emptyTitle: '暂无 Issue',
      emptySubtitle: '仓库还没有提交过 Issue',
    );
  }
}

class _IssueCard extends StatelessWidget {
  final Issue issue;
  final VoidCallback onTap;

  const _IssueCard({required this.issue, required this.onTap});

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
                  _StateChip(state: issue.state),
                  const SizedBox(width: 8),
                  Text('#${issue.number}', style: theme.textTheme.bodySmall),
                  const Spacer(),
                  Text(formatRelativeTime(issue.createdAt),
                      style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                issue.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              if (issue.labels.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: issue.labels
                      .map((label) => _LabelChip(label: label))
                      .toList(),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (issue.user != null) ...[
                    AppAvatar(url: issue.user!.avatarUrl, size: 22, radius: 6),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      issue.user?.login ?? '匿名用户',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Icon(Icons.chat_bubble_outline,
                      size: 16, color: context.mutedForeground),
                  const SizedBox(width: 4),
                  Text('${issue.comments}', style: theme.textTheme.bodySmall),
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
    final open = state == 'open';
    final color = open ? AppColors.success : AppColors.closed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        open ? '开放' : '已关闭',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  final Label label;

  const _LabelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final clean = label.color.replaceAll('#', '');
    final value = int.tryParse(clean, radix: 16);
    final color =
        value == null ? context.mutedForeground : Color(0xFF000000 | value);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = dark ? Colors.black87 : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.name,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }
}
