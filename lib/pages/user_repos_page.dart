import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../widgets/paged_repo_list.dart';

/// 指定用户的仓库列表。
class UserReposPage extends StatelessWidget {
  final String username;

  const UserReposPage({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$username 的仓库')),
      body: PagedRepoList(
        loadPage: (page) =>
            GiteeApi.getUserRepos(username: username, page: page, perPage: 20),
        emptyTitle: '暂无仓库',
        emptySubtitle: '该用户还没有公开仓库',
      ),
    );
  }
}
