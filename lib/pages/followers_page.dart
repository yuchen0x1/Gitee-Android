import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../widgets/paged_user_list.dart';

/// 我的粉丝列表。
class FollowersPage extends StatelessWidget {
  const FollowersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的粉丝')),
      body: PagedUserList(
        loadPage: (page) => GiteeApi.getFollowers(page: page, perPage: 20),
        emptyTitle: '还没有粉丝',
        emptySubtitle: '发布更多内容让更多人关注你',
      ),
    );
  }
}
