import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../models/gitee_api_entities.dart';
import '../theme/app_theme.dart';
import '../widgets/paged_list_view.dart';
import '../widgets/time_format.dart';
import 'gist_detail_page.dart';
import 'gist_composer_page.dart';

/// 我的代码片段（Gist）列表。
class GistListPage extends StatefulWidget {
  const GistListPage({super.key});

  @override
  State<GistListPage> createState() => _GistListPageState();
}

class _GistListPageState extends State<GistListPage> {
  late final PagedListViewState<Gist> listKey;

  final GlobalKey<PagedListViewState<Gist>> _listKey =
      GlobalKey<PagedListViewState<Gist>>();

  Future<List<Gist>> _loadPage(int page) =>
      GiteeApi.getGists(page: page, perPage: 20);

  Future<void> _createGist() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const GistComposerPage()),
    );
    if (created == true) _listKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('代码片段'),
        actions: [
          IconButton(
            tooltip: '新建代码片段',
            icon: const Icon(Icons.add),
            onPressed: _createGist,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'gist-create',
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        onPressed: _createGist,
        child: const Icon(Icons.add),
      ),
      body: PagedListView<Gist>(
        key: _listKey,
        loadPage: _loadPage,
        emptyIcon: Icons.code_outlined,
        emptyTitle: '还没有代码片段',
        emptySubtitle: '点右下角按钮创建你的第一个 Gist',
        itemBuilder: (context, gist) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Icon(
              gist.isPublic ? Icons.public_outlined : Icons.lock_outline,
              color: gist.isPublic ? AppColors.success : AppColors.textTertiary,
            ),
            title: Text(
              gist.description.isEmpty
                  ? (gist.files.isNotEmpty
                      ? gist.files.first.filename
                      : '无标题片段')
                  : gist.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${gist.files.length} 个文件 · '
                '${gist.isPublic ? '公开' : '私密'} · '
                '更新于 ${formatRelativeTime(gist.updatedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => GistDetailPage(gistId: gist.id),
                  ),
                )
                .then((_) => _listKey.currentState?.refresh()),
          ),
        ),
      ),
    );
  }
}
