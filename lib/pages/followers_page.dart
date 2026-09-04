import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../widgets/paged_user_list.dart';

/// 粉丝列表；传 [username] 查看任意用户，否则查看当前登录用户。
class FollowersPage extends StatelessWidget {
  final String? username;

  const FollowersPage({super.key, this.username});

  @override
  Widget build(BuildContext context) {
    final isSelf = username == null || username!.isEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(isSelf ? '我的粉丝' : '@$username 的粉丝')),
      body: PagedUserList(
        loadPage: (page) => isSelf
            ? GiteeApi.getFollowers(page: page, perPage: 20)
            : GiteeApi.getUserFollowers(username!, page: page, perPage: 20),
        emptyTitle: '还没有粉丝',
        emptySubtitle: '发布更多内容让更多人关注你',
      ),
    );
  }
}
