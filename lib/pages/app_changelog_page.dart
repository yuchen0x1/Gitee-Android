import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../services/update_service.dart';
import '../widgets/release_list_view.dart';
import 'release_detail_page.dart';

/// 应用更新日志：列出本仓库在 Gitee 的全部版本发布，
/// 数据与「检查更新」同源，已登录时走授权接口，不受匿名限流影响。
class AppChangelogPage extends StatelessWidget {
  const AppChangelogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('更新日志')),
      body: ReleaseListView(
        loadPage: (page) => GiteeApi.getReleases(
          UpdateService.repositoryOwner,
          UpdateService.repositoryName,
          page: page,
          perPage: 20,
        ),
        onTap: (release) => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReleaseDetailPage(release: release),
          ),
        ),
      ),
    );
  }
}
