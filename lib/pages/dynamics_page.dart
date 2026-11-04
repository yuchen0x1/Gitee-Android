import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../models/event.dart';
import '../models/notification.dart';
import '../theme/app_theme.dart';
import '../utils/error_message.dart';
import '../utils/launch_url.dart';
import '../widgets/anim.dart';
import '../widgets/app_image.dart';
import '../widgets/glass_surface.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/notification_group_list.dart';
import '../widgets/state_views.dart';
import '../widgets/time_format.dart';

/// 动态页：通知 + 用户动态两个 Tab。
class DynamicsPage extends StatelessWidget {
  final String? userLogin;
  final ValueChanged<int>? onUnreadCountChanged;

  const DynamicsPage({
    super.key,
    this.userLogin,
    this.onUnreadCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('动态'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(48),
            child: GlassSurface(
              borderRadius: BorderRadius.zero,
              bordered: false,
              child: TabBar(
                tabs: [Tab(text: '通知'), Tab(text: '动态')],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            NotificationsView(onUnreadCountChanged: onUnreadCountChanged),
            EventsView(userLogin: userLogin),
          ],
        ),
      ),
    );
  }
}

class NotificationsView extends StatefulWidget {
  final ValueChanged<int>? onUnreadCountChanged;

  const NotificationsView({super.key, this.onUnreadCountChanged});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final List<AppNotification> _items = [];
  final ScrollController _scroll = ScrollController();
  bool _loading = true;
  bool _requestInFlight = false;
  int _generation = 0;
  bool _hasMore = true;
  int _page = 1;
  int _unreadCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_requestInFlight && !refresh) return;
    final generation = ++_generation;
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _items.clear();
    }
    if (!_hasMore && !refresh) return;
    setState(() {
      _loading = true;
      _requestInFlight = true;
    });
    try {
      final list = await GiteeApi.getNotifications(page: _page, perPage: 20);
      final unread = await GiteeApi.getNotificationCount();
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _requestInFlight = false;
        _error = null;
        _items.addAll(list);
        _unreadCount = unread;
        widget.onUnreadCountChanged?.call(unread);
        if (list.length < 20) _hasMore = false;
        _page++;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _requestInFlight = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 100) {
      if (!_requestInFlight && !_loading && _hasMore) _load();
    }
  }

  Future<void> _open(AppNotification item) async {
    if (item.htmlUrl.isEmpty) return;
    await launchExternalUrl(item.htmlUrl);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading) return const SkeletonList(variant: SkeletonVariant.commitRow);
    if (_items.isEmpty && _error != null) {
      return ErrorState(message: _error!, onRetry: () => _load(refresh: true));
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none,
        title: '暂无通知',
        subtitle: '有新通知时会第一时间出现在这里',
      );
    }
    return Column(
      children: [
        if (_unreadCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.mark_email_unread_outlined,
                    size: 18, color: AppColors.primaryRed),
                const SizedBox(width: 8),
                Text('$_unreadCount 条未读通知',
                    style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    try {
                      await GiteeApi.markAllNotificationsRead();
                      if (mounted) {
                        setState(() => _unreadCount = 0);
                        widget.onUnreadCountChanged?.call(0);
                      }
                    } catch (_) {}
                  },
                  child: const Text('全部已读'),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primaryRed,
            onRefresh: () => _load(refresh: true),
            child: NotificationGroupList(
              items: _items,
              controller: _scroll,
              loading: _loading,
              hasMore: _hasMore,
              onTap: _open,
              onDismiss: (item) {
                final index = _items.indexOf(item);
                if (index >= 0) {
                  _items.removeAt(index);
                  setState(() {
                    if (item.unread && _unreadCount > 0) _unreadCount--;
                  });
                  widget.onUnreadCountChanged?.call(_unreadCount);
                  GiteeApi.markNotificationRead(item.id)
                      .then((_) {}, onError: (_) {});
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}

class EventsView extends StatefulWidget {
  final String? userLogin;

  const EventsView({super.key, this.userLogin});

  @override
  State<EventsView> createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> {
  final List<Event> _items = [];
  final ScrollController _scroll = ScrollController();
  bool _loading = true;
  bool _requestInFlight = false;
  int _generation = 0;
  bool _hasMore = true;
  String? _prevId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    if (widget.userLogin != null && widget.userLogin!.isNotEmpty) _load();
  }

  @override
  void didUpdateWidget(covariant EventsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userLogin != widget.userLogin) {
      _items.clear();
      _prevId = null;
      _hasMore = true;
      _error = null;
      _load(refresh: true);
    }
  }

  Future<void> _load({bool refresh = false}) async {
    final login = widget.userLogin;
    if (login == null || login.isEmpty) return;
    if (_requestInFlight && !refresh) return;
    final generation = ++_generation;
    if (refresh) {
      _prevId = null;
      _hasMore = true;
      _items.clear();
    }
    if (!_hasMore && !refresh) return;
    setState(() {
      _loading = true;
      _requestInFlight = true;
    });
    try {
      final list = await GiteeApi.getUserEvents(
        login,
        prevId: _prevId,
        limit: 20,
      );
      if (!mounted || generation != _generation) return;
      final seen = _items.map((item) => item.id).toSet();
      final fresh =
          list.where((item) => item.id.isEmpty || seen.add(item.id)).toList();
      setState(() {
        _loading = false;
        _requestInFlight = false;
        _error = null;
        _items.addAll(fresh);
        _prevId = fresh.isNotEmpty ? fresh.last.id : _prevId;
        if (list.length < 20 || fresh.isEmpty) _hasMore = false;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _requestInFlight = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 100) {
      if (!_requestInFlight && !_loading && _hasMore) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final login = widget.userLogin;
    if (login == null || login.isEmpty) {
      return const EmptyState(
        key: ValueKey('events-empty-user'),
        icon: Icons.person_search,
        title: '正在获取用户信息',
        subtitle: '加载登录用户后将展示最近动态',
      );
    }
    Widget body;
    if (_items.isEmpty && _loading) {
      body = const SkeletonList(
        key: ValueKey('events-loading'),
        variant: SkeletonVariant.commitRow,
      );
    } else if (_items.isEmpty && _error != null) {
      body = ErrorState(
        key: const ValueKey('events-error'),
        message: _error!,
        onRetry: () => _load(refresh: true),
      );
    } else if (_items.isEmpty) {
      body = const EmptyState(
        key: ValueKey('events-empty'),
        icon: Icons.dynamic_feed,
        title: '暂无动态',
        subtitle: '关注用户产生新动作后会出现在这里',
      );
    } else {
      body = RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: () => _load(refresh: true),
        child: ListView.builder(
          key: const ValueKey('events-list'),
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: _items.length + 1,
          itemBuilder: (context, index) {
            if (index >= _items.length) {
              return ListFooter(loading: _loading, hasMore: _hasMore);
            }
            return FadeSlideIn(
              index: index,
              child: _EventCard(event: _items[index]),
            );
          },
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: body,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}

class _EventCard extends StatelessWidget {
  final Event event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(url: event.actor?.avatarUrl ?? '', size: 40, radius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_eventIcon(event.type),
                          size: 18, color: AppColors.primaryRed),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.actor?.login ?? '',
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(event.payload, style: theme.textTheme.bodyMedium),
                  if (event.repoName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(event.repoName, style: theme.textTheme.bodySmall),
                  ],
                  const SizedBox(height: 6),
                  Text(formatRelativeTime(event.createdAt),
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'PushEvent':
        return Icons.upload_file;
      case 'IssuesEvent':
        return Icons.bug_report_outlined;
      case 'WatchEvent':
        return Icons.star;
      case 'ForkEvent':
        return Icons.call_split;
      case 'CreateEvent':
        return Icons.create_new_folder_outlined;
      case 'ReleaseEvent':
        return Icons.new_releases_outlined;
      default:
        return Icons.bolt;
    }
  }
}
