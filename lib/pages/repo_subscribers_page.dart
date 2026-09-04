import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../widgets/paged_user_list.dart';

/// 仓库关注者（Watchers）列表。
class RepoSubscribersPage extends StatelessWidget {
  final String owner;
  final String repo;

  const RepoSubscribersPage({super.key, required this.owner, required this.repo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$owner/$repo 的关注者')),
      body: PagedUserList(
        loadPage: (page) =>
            GiteeApi.getRepoSubscribers(owner, repo, page: page, perPage: 20),
        emptyTitle: '还没有人关注',
        emptySubtitle: '关注仓库后会显示在这里',
      ),
    );
  }
}
