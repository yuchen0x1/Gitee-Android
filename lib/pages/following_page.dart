import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../widgets/paged_user_list.dart';

/// 我的关注列表。
class FollowingPage extends StatelessWidget {
  const FollowingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的关注')),
      body: PagedUserList(
        loadPage: (page) => GiteeApi.getFollowing(page: page, perPage: 20),
        emptyTitle: '还没有关注任何人',
        emptySubtitle: '去用户主页看看感兴趣的人',
      ),
    );
  }
}
