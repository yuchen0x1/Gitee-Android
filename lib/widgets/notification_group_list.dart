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
  final void Function(AppNotification item)? onDismiss;

  const NotificationGroupList({
    super.key,
    required this.items,
    required this.controller,
    required this.loading,
    required this.hasMore,
    required this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<AppNotification>>{};
    for (final item in items) {
      final key = item.repository.isEmpty ? '其他' : item.repository;
      groups.putIfAbsent(key, () => []).add(item);
    }
    return ListView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length + 1,
      itemBuilder: (context, index) {
        if (index >= groups.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ListFooter(loading: loading, hasMore: hasMore),
          );
        }
        final entry = groups.entries.elementAt(index);
        final repo = entry.key;
        final groupItems = entry.value;
        return _RepoGroup(
          repo: repo,
          items: groupItems,
          onTap: onTap,
          onDismiss: onDismiss,
        );
      },
    );
  }
}

class _RepoGroup extends StatelessWidget {
  final String repo;
  final List<AppNotification> items;
  final void Function(AppNotification item) onTap;
  final void Function(AppNotification item)? onDismiss;

  const _RepoGroup({
    required this.repo,
    required this.items,
    required this.onTap,
    this.onDismiss,
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
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: unread > 0
                ? Badge(
                    label: Text('$unread'),
                    backgroundColor: AppColors.primaryRed,
                    child: const Icon(Icons.notifications_active_outlined, color: AppColors.primaryRed),
                  )
                : const Icon(Icons.notifications_none_outlined),
            title: Text(repo,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600, fontSize: 14.5)),
            subtitle: Text('${items.length} 条通知${unread > 0 ? " · $unread 未读" : ''}'),
            children: items.map((item) {
              return Dismissible(
                key: ValueKey('notification_${item.id}_${items.indexOf(item)}'),
                direction: onDismiss != null
                    ? DismissDirection.endToStart
                    : DismissDirection.none,
                background: onDismiss != null
                    ? Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.done_all, color: Colors.white),
                      )
                    : null,
                onDismissed: onDismiss != null ? (_) => onDismiss!(item) : null,
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
                          ? Border.all(color: AppColors.primaryRed.withValues(alpha: 0.3), width: 0.8)
                          : null,
                    ),
                    child: Icon(_icon(item.type),
                        size: 16,
                        color: item.unread
                            ? AppColors.primaryRed
                            : AppColors.textTertiary),
                  ),
                  title: Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight:
                              item.unread ? FontWeight.w600 : FontWeight.normal)),
                  subtitle: Text(formatRelativeTime(item.updatedAt),
                      style: theme.textTheme.bodySmall),
                  onTap: () => onTap(item),
                ),
              );
            }).toList(),
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
