import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../models/repo.dart';
import '../widgets/paged_list_view.dart';
import '../widgets/repo_card.dart';
import 'create_repo_page.dart';

/// 我的仓库列表页。
class ReposPage extends StatefulWidget {
  const ReposPage({super.key});

  @override
  State<ReposPage> createState() => _ReposPageState();
}

class _ReposPageState extends State<ReposPage> {
  final GlobalKey<PagedListViewState<Repo>> _listKey =
      GlobalKey<PagedListViewState<Repo>>();

  Future<void> _createRepo() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateRepoPage()),
    );
    if (created != true || !mounted) return;
    await _listKey.currentState?.refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('仓库已创建')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('仓库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '创建仓库',
            onPressed: _createRepo,
          ),
        ],
      ),
      body: PagedListView<Repo>(
        key: _listKey,
        loadPage: (page) => GiteeApi.getUserRepos(page: page, perPage: 20),
        itemBuilder: (context, repo) => RepoCard(repo: repo),
        emptyIcon: Icons.folder_open,
        emptyTitle: '暂无仓库',
        emptySubtitle: '去 Gitee 创建仓库后下拉刷新即可看到',
      ),
    );
  }
}
