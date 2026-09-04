import 'package:flutter/material.dart';
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
  final bool supportsPagination;
  final EdgeInsetsGeometry padding;

  const PagedListView({
    super.key,
    required this.loadPage,
    required this.itemBuilder,
    required this.emptyTitle,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptySubtitle = '',
    this.supportsPagination = true,
    this.padding = const EdgeInsets.all(16),
  });

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
      _error = null;
    });
    try {
      final list = await widget.loadPage(_page);
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _requestInFlight = false;
        _error = null;
        _items.addAll(list);
        // ponytail: 以页大小 20 判定是否还有更多；perPage 变更时需同步调整。
        if (!widget.supportsPagination || list.length < 20) _hasMore = false;
        _page++;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _requestInFlight = false;
          _error = e.toString();
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
    if (_items.isEmpty && _loading) return const SkeletonList();
    if (_items.isEmpty && _error != null) {
      return ErrorState(message: _error!, onRetry: () => _load(refresh: true));
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        subtitle: widget.emptySubtitle,
        actionLabel: '刷新',
        onAction: () => _load(refresh: true),
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryRed,
      onRefresh: () => _load(refresh: true),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: _items.length + (_hasMore || _loading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return ListFooter(loading: _loading, hasMore: _hasMore);
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
