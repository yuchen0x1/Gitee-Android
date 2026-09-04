import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../models/event.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_views.dart';
import '../widgets/time_format.dart';

/// 仓库动态列表：Push / Star / Fork / Release 等时间线。
class RepoEventsPage extends StatefulWidget {
  final String owner;
  final String repo;

  const RepoEventsPage({super.key, required this.owner, required this.repo});

  @override
  State<RepoEventsPage> createState() => _RepoEventsPageState();
}

class _RepoEventsPageState extends State<RepoEventsPage> {
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
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
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
      final list = await GiteeApi.getRepoEvents(
        widget.owner,
        widget.repo,
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
          _error = e.toString();
        });
      }
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 100) {
      if (!_loading && _hasMore) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading) return const Scaffold(body: SkeletonList());
    if (_items.isEmpty && _error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('仓库动态')),
        body: ErrorState(message: _error!, onRetry: () => _load(refresh: true)),
      );
    }
    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('仓库动态')),
        body: RefreshIndicator(
          color: AppColors.primaryRed,
          onRefresh: () => _load(refresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              EmptyState(
                icon: Icons.timeline,
                title: '暂无动态',
                subtitle: '仓库还没有产生动态',
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('仓库动态')),
      body: RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: () => _load(refresh: true),
        child: ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: _items.length + 1,
          itemBuilder: (context, index) {
            if (index >= _items.length) {
              return ListFooter(loading: _loading, hasMore: _hasMore);
            }
            return _RepoEventCard(event: _items[index]);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}

class _RepoEventCard extends StatelessWidget {
  final Event event;

  const _RepoEventCard({required this.event});

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
                          size: 16, color: AppColors.primaryRed),
                      const SizedBox(width: 6),
                      Text(
                        event.actor?.login ?? '匿名',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(event.payload, style: theme.textTheme.bodyMedium),
                  if (event.createdAt.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(formatRelativeTime(event.createdAt),
                        style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _eventIcon(String type) {
  switch (type) {
    case 'PushEvent':
      return Icons.arrow_upward;
    case 'WatchEvent':
      return Icons.star;
    case 'ForkEvent':
      return Icons.call_split;
    case 'IssuesEvent':
      return Icons.bug_report;
    case 'PullRequestEvent':
      return Icons.merge_type;
    case 'ReleaseEvent':
      return Icons.auto_awesome;
    default:
      return Icons.timeline;
  }
}
