import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../widgets/paged_repo_list.dart';

class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的订阅')),
      body: PagedRepoList(
        loadPage: (page) => GiteeApi.getSubscriptions(page: page, perPage: 20),
        emptyTitle: '还没有订阅仓库',
        emptySubtitle: '订阅仓库后可以在这里集中查看',
      ),
    );
  }
}
