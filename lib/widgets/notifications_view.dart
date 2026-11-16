import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../models/notification.dart';
import '../utils/error_message.dart';
import '../utils/launch_url.dart';
import 'notification_group_list.dart';
import 'skeleton_list.dart';
import 'state_views.dart';

/// Server-filtered inbox. Reads never discard visible data until they succeed;
/// writes only update local state after the server acknowledges the operation.
class NotificationsView extends StatefulWidget {
  final ValueChanged<int>? onUnreadCountChanged;

  const NotificationsView({super.key, this.onUnreadCountChanged});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final List<AppNotification> _items = [];
  final ScrollController _scroll = ScrollController();
  bool _unreadOnly = true;
  bool _loading = true;
  bool _mutating = false;
  bool _hasMore = true;
  bool _failedRefresh = false;
  int _generation = 0;
  int _page = 1;
  int? _unreadCount;
  String? _error;
  bool _countFailed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (_mutating || (_loading && !refresh) || (!_hasMore && !refresh)) return;
    final generation = ++_generation;
    final requestedPage = refresh ? 1 : _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await GiteeApi.getNotifications(
        page: requestedPage,
        perPage: 20,
        unread: _unreadOnly,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (refresh) _items.clear();
        final seen = _items.map((item) => item.id).toSet();
        _items.addAll(list.where((item) => seen.add(item.id)));
        _hasMore = list.length >= 20;
        _page = requestedPage + 1;
      });
      // A count failure must not turn a successfully fetched list into an error.
      await _syncCount(generation, forceRefresh: refresh);
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = friendlyError(e);
          _failedRefresh = refresh;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _syncCount(int generation, {bool forceRefresh = true}) async {
    try {
      final count = await GiteeApi.getNotificationCount(
        forceRefresh: forceRefresh,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _unreadCount = count;
        _countFailed = false;
      });
      widget.onUnreadCountChanged?.call(count);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _countFailed = true);
      }
    }
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 100 &&
        !_loading &&
        !_mutating &&
        _error == null &&
        _hasMore) {
      _load();
    }
  }

  void _switchFilter(bool unreadOnly) {
    if (_mutating || unreadOnly == _unreadOnly) return;
    setState(() {
      _unreadOnly = unreadOnly;
      _items.clear();
      _error = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _load(refresh: true);
  }

  Future<void> _markRead(AppNotification item) async {
    if (_mutating || !item.unread || item.id.isEmpty) return;
    final generation = ++_generation;
    setState(() {
      _mutating = true;
      _loading = false;
    });
    var succeeded = false;
    try {
      await GiteeApi.markNotificationRead(item.id);
      if (!mounted || generation != _generation) return;
      setState(() {
        final index = _items.indexWhere((entry) => entry.id == item.id);
        if (index >= 0) _items[index] = _items[index].asRead();
        if (_unreadOnly) _items.removeWhere((entry) => entry.id == item.id);
        if ((_unreadCount ?? 0) > 0) _unreadCount = _unreadCount! - 1;
      });
      if (_unreadCount != null) {
        widget.onUnreadCountChanged?.call(_unreadCount!);
      }
      succeeded = true;
      await _syncCount(generation);
    } catch (e) {
      if (mounted) _showError('标记已读失败：${friendlyError(e)}');
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _mutating = false);
      }
    }
    // Removing an unread item shifts server page offsets. Rebase from page 1
    // before allowing further pagination so the next unread item is not skipped.
    if (mounted && succeeded && _unreadOnly) await _load(refresh: true);
  }

  Future<void> _markAllRead() async {
    if (_mutating) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('将所有通知标为已读？'),
        content: const Text('此操作会标记账号的全部通知，包括尚未加载的通知。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('全部已读')),
        ],
      ),
    );
    if (confirmed != true || !mounted || _mutating) return;
    final generation = ++_generation;
    setState(() {
      _mutating = true;
      _loading = false;
    });
    try {
      await GiteeApi.markAllNotificationsRead();
      if (!mounted || generation != _generation) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          _items[i] = _items[i].asRead();
        }
        if (_unreadOnly) {
          _items.clear();
          _hasMore = false;
          _page = 1;
        }
        _unreadCount = 0;
        _countFailed = false;
        _error = null;
      });
      widget.onUnreadCountChanged?.call(0);
      await _syncCount(generation);
    } catch (e) {
      if (mounted) _showError('全部标记失败：${friendlyError(e)}');
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _mutating = false);
      }
    }
  }

  Future<void> _open(AppNotification item) async {
    try {
      if (item.htmlUrl.isEmpty || !await launchExternalUrl(item.htmlUrl)) {
        if (mounted) _showError('无法打开此通知的链接');
      }
    } catch (_) {
      if (mounted) _showError('无法打开此通知的链接');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final canMarkAll = !_mutating &&
        ((_unreadCount ?? 0) > 0 || _items.any((item) => item.unread));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                  label: const Text('未读'),
                  selected: _unreadOnly,
                  onSelected: _mutating ? null : (_) => _switchFilter(true)),
              ChoiceChip(
                  label: const Text('全部'),
                  selected: !_unreadOnly,
                  onSelected: _mutating ? null : (_) => _switchFilter(false)),
              TextButton.icon(
                onPressed: canMarkAll ? _markAllRead : null,
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('全部已读'),
              ),
              IconButton(
                tooltip: '刷新通知',
                onPressed:
                    _loading || _mutating ? null : () => _load(refresh: true),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
                _countFailed
                    ? '未读计数暂不可用，可刷新重试'
                    : _unreadCount == null
                        ? '正在获取未读计数…'
                        : '$_unreadCount 条未读通知',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        if (_mutating) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_items.isEmpty && _loading) {
      return const SkeletonList(variant: SkeletonVariant.commitRow);
    }
    if (_items.isEmpty && _error != null) {
      return ErrorState(message: _error!, onRetry: () => _load(refresh: true));
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: _unreadOnly
            ? Icons.mark_email_read_outlined
            : Icons.notifications_none,
        title: _unreadOnly ? '未读通知已处理完' : '暂无通知',
        subtitle: _unreadOnly ? '可切换「全部」查看已读通知，或刷新检查新通知' : '可刷新检查新通知',
        actionLabel: '刷新',
        onAction: _mutating ? null : () => _load(refresh: true),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: NotificationGroupList(
        items: _items,
        controller: _scroll,
        loading: _loading,
        hasMore: _hasMore,
        error: _error,
        onRetry: () => _load(refresh: _failedRefresh),
        onLoadMore: _mutating ? null : () => _load(),
        onTap: _open,
        onMarkRead: _mutating ? null : _markRead,
      ),
    );
  }

  @override
  void dispose() {
    _generation++;
    _scroll.dispose();
    super.dispose();
  }
}
