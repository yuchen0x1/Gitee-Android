import 'package:flutter/material.dart';
import '../utils/error_message.dart';
import '../theme/app_theme.dart';
import 'skeleton_list.dart';
import 'state_views.dart';

/// 泛型分页列表：统一骨架屏、空/错误态、下拉刷新与滚动加载。
/// 各列表页只提供 [loadPage] 与 [itemBuilder]，不再各自维护分页状态机。
class PagedListView<T> extends StatefulWidget {
  final Future<List<T>> Function(int page) loadPage;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final String? emptyActionLabel;
  final VoidCallback? emptyOnAction;
  final bool supportsPagination;
  final int pageSize;
  final EdgeInsetsGeometry padding;

  const PagedListView({
    super.key,
    required this.loadPage,
    required this.itemBuilder,
    required this.emptyTitle,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptySubtitle = '',
    this.emptyActionLabel,
    this.emptyOnAction,
    this.supportsPagination = true,
    this.pageSize = 20,
    this.padding = const EdgeInsets.all(16),
  }) : assert(pageSize > 0);

  @override
  State<PagedListView<T>> createState() => PagedListViewState<T>();
}

class PagedListViewState<T> extends State<PagedListView<T>> {
  final List<T> _items = [];
  final ScrollController _scroll = ScrollController();
  bool _loading = true;
  bool _requestInFlight = false;
  int _generation = 0;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  bool _failedRefresh = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  /// 供外部触发刷新（如创建仓库后）。
  Future<void> refresh() => _load(refresh: true);

  Future<void> _load({bool refresh = false}) async {
    if (_requestInFlight && !refresh) return;
    if (!_hasMore && !refresh) return;
    final generation = ++_generation;
    final requestedPage = refresh ? 1 : _page;
    setState(() {
      _loading = true;
      _requestInFlight = true;
      _error = null;
    });
    try {
      final list = await widget.loadPage(requestedPage);
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _requestInFlight = false;
        _error = null;
        if (refresh) _items.clear();
        _items.addAll(list);
        _hasMore = widget.supportsPagination && list.length >= widget.pageSize;
        _page = requestedPage + 1;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _requestInFlight = false;
          _error = friendlyError(e);
          _failedRefresh = refresh;
        });
      }
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 100) {
      if (!_requestInFlight && !_loading && _hasMore && _error == null) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading) return const SkeletonList();
    if (_items.isEmpty && _error != null) {
      return ErrorState(message: _error!, onRetry: () => _load(refresh: true));
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        subtitle: widget.emptySubtitle,
        actionLabel: widget.emptyActionLabel ?? '刷新',
        onAction: widget.emptyOnAction ?? () => _load(refresh: true),
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryRed,
      onRefresh: () => _load(refresh: true),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return ListFooter(
                loading: _loading,
                hasMore: _hasMore,
                error: _error,
                onRetry: () => _load(refresh: _failedRefresh),
                onLoadMore: () => _load());
          }
          return widget.itemBuilder(context, _items[index]);
        },
      ),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}
