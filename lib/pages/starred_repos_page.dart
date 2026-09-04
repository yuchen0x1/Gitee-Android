import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../widgets/paged_repo_list.dart';

/// 我 Star 过的仓库列表。
class StarredReposPage extends StatelessWidget {
  const StarredReposPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的 Star')),
      body: PagedRepoList(
        loadPage: (page) => GiteeApi.getStarredRepos(page: page),
        supportsPagination: true,
        emptyTitle: '还没有 Star 的仓库',
        emptySubtitle: '去仓库详情页点亮 Star 吧',
      ),
    );
  }
}
