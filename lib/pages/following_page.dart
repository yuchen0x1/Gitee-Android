import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../widgets/paged_user_list.dart';

/// 关注列表；传 [username] 查看任意用户，否则查看当前登录用户。
class FollowingPage extends StatelessWidget {
  final String? username;

  const FollowingPage({super.key, this.username});

  @override
  Widget build(BuildContext context) {
    final isSelf = username == null || username!.isEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(isSelf ? '我的关注' : '@$username 的关注')),
      body: PagedUserList(
        loadPage: (page) => isSelf
            ? GiteeApi.getFollowing(page: page, perPage: 20)
            : GiteeApi.getUserFollowing(username!, page: page, perPage: 20),
        emptyTitle: '还没有关注任何人',
        emptySubtitle: '去用户主页看看感兴趣的人',
      ),
    );
  }
}
