import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../widgets/release_list_view.dart';
import 'release_detail_page.dart';

/// 应用更新日志：列出本仓库在 GitHub 的全部版本发布，
/// 数据与「检查更新」同源，匿名访问 GitHub REST API。
class AppChangelogPage extends StatelessWidget {
  const AppChangelogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('更新日志')),
      body: ReleaseListView(
        loadPage: (page) =>
            UpdateService.shared.fetchReleases(page: page, perPage: 20),
        onTap: (release) => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReleaseDetailPage(release: release),
          ),
        ),
      ),
    );
  }
}
