import 'package:flutter/material.dart';
import '../models/repo.dart';
import 'paged_list_view.dart';
import 'repo_card.dart';

/// 仓库分页列表（基于 [PagedListView]）。
class PagedRepoList extends StatelessWidget {
  final Future<List<Repo>> Function(int page) loadPage;
  final String emptyTitle;
  final String emptySubtitle;
  final bool supportsPagination;

  const PagedRepoList({
    super.key,
    required this.loadPage,
    required this.emptyTitle,
    this.emptySubtitle = '',
    this.supportsPagination = true,
  });

  @override
  Widget build(BuildContext context) {
    return PagedListView<Repo>(
      loadPage: loadPage,
      itemBuilder: (context, repo) => RepoCard(repo: repo),
      emptyIcon: Icons.folder_open,
      emptyTitle: emptyTitle,
      emptySubtitle: emptySubtitle,
      supportsPagination: supportsPagination,
    );
  }
}
