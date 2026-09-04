import 'package:flutter/material.dart';
import '../models/user.dart';
import 'paged_list_view.dart';
import 'user_tile.dart';

/// 用户分页列表（基于 [PagedListView]）。
class PagedUserList extends StatelessWidget {
  final Future<List<User>> Function(int page) loadPage;
  final String emptyTitle;
  final String emptySubtitle;

  const PagedUserList({
    super.key,
    required this.loadPage,
    required this.emptyTitle,
    this.emptySubtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    return PagedListView<User>(
      loadPage: loadPage,
      itemBuilder: (context, user) => UserTile(user: user),
      emptyIcon: Icons.people_outline,
      emptyTitle: emptyTitle,
      emptySubtitle: emptySubtitle,
    );
  }
}
