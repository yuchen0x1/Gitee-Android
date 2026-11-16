import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../theme/app_theme.dart';
import 'glass_surface.dart';
import 'state_views.dart';
import 'time_format.dart';

/// 按仓库分组的通知列表。
class NotificationGroupList extends StatelessWidget {
  final List<AppNotification> items;
  final ScrollController controller;
  final bool loading;
  final bool hasMore;
  final void Function(AppNotification item) onTap;
  final void Function(AppNotification item)? onMarkRead;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onLoadMore;

  const NotificationGroupList({
    super.key,
    required this.items,
    required this.controller,
    required this.loading,
    required this.hasMore,
    required this.onTap,
    this.onMarkRead,
    this.error,
    this.onRetry,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<AppNotification>>{};
    for (final item in items) {
      final key = item.repository.isEmpty ? '其他' : item.repository;
      groups.putIfAbsent(key, () => []).add(item);
    }
    final entries = groups.entries.toList();
    return ListView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length + 1,
      itemBuilder: (context, index) {
        if (index >= groups.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ListFooter(
                loading: loading,
                hasMore: hasMore,
                error: error,
                onRetry: onRetry,
                onLoadMore: onLoadMore),
          );
        }
        final entry = entries[index];
        final repo = entry.key;
        final groupItems = entry.value;
        return _RepoGroup(
          repo: repo,
          items: groupItems,
          onTap: onTap,
          onMarkRead: onMarkRead,
        );
      },
    );
  }
}

class _RepoGroup extends StatelessWidget {
  final String repo;
  final List<AppNotification> items;
  final void Function(AppNotification item) onTap;
  final void Function(AppNotification item)? onMarkRead;

  const _RepoGroup({
    required this.repo,
    required this.items,
    required this.onTap,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = items.where((n) => n.unread).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GlassSurface(
        simple: true,
        borderRadius: BorderRadius.circular(16),
        child: Material(
          type: MaterialType.transparency,
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey('notification_group_$repo'),
              initiallyExpanded: true,
              leading: unread > 0
                  ? Badge(
                      label: Text('$unread'),
                      backgroundColor: AppColors.primaryRed,
                      child: const Icon(Icons.notifications_active_outlined,
                          color: AppColors.primaryRed),
                    )
                  : const Icon(Icons.notifications_none_outlined),
              title: Text(repo,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600, fontSize: 14.5)),
              subtitle: Text(
                  '${items.length} 条通知${unread > 0 ? " · $unread 未读" : ''}'),
              children: items.map((item) {
                return Dismissible(
                  key: ValueKey('notification_${item.id}'),
                  direction:
                      onMarkRead != null && item.unread && item.id.isNotEmpty
                          ? DismissDirection.endToStart
                          : DismissDirection.none,
                  background: onMarkRead != null && item.unread
                      ? Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              const Icon(Icons.done_all, color: Colors.white),
                        )
                      : null,
                  // Keep the row until the server confirms the read operation.
                  // Returning immediately also leaves failed swipes retryable.
                  confirmDismiss: (_) async {
                    onMarkRead?.call(item);
                    return false;
                  },
                  child: ListTile(
                    dense: true,
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: item.unread
                            ? AppColors.primaryRed.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: item.unread
                            ? Border.all(
                                color:
                                    AppColors.primaryRed.withValues(alpha: 0.3),
                                width: 0.8)
                            : null,
                      ),
                      child: Icon(_icon(item.type),
                          size: 16,
                          color: item.unread
                              ? AppColors.primaryRed
                              : context.mutedForeground),
                    ),
                    title: Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: item.unread
                                ? FontWeight.w600
                                : FontWeight.normal)),
                    subtitle: Text(formatRelativeTime(item.updatedAt),
                        style: theme.textTheme.bodySmall),
                    trailing: item.unread && item.id.isNotEmpty
                        ? IconButton(
                            tooltip: '标记已读',
                            onPressed: onMarkRead == null
                                ? null
                                : () => onMarkRead!(item),
                            icon: const Icon(Icons.mark_email_read_outlined,
                                size: 20),
                          )
                        : null,
                    onTap: () => onTap(item),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

IconData _icon(String type) {
  switch (type) {
    case 'PullRequestEvent':
      return Icons.call_split;
    case 'IssueEvent':
      return Icons.bug_report;
    case 'PushEvent':
      return Icons.arrow_upward;
    case 'WatchEvent':
      return Icons.star;
    case 'ForkEvent':
      return Icons.call_split;
    case 'ReleaseEvent':
      return Icons.auto_awesome;
    case 'MemberEvent':
      return Icons.person_add;
    default:
      return Icons.notifications;
  }
}
