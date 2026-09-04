import 'package:flutter/material.dart';
import '../models/release.dart';
import '../theme/app_theme.dart';
import '../utils/launch_url.dart';
import '../widgets/app_markdown.dart';
import '../widgets/time_format.dart';

/// Release 详情页：发布说明与附件下载入口。
class ReleaseDetailPage extends StatelessWidget {
  final Release release;

  const ReleaseDetailPage({super.key, required this.release});

  Future<void> _open(String url) async {
    await launchExternalUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(release.tagName, overflow: TextOverflow.ellipsis),
        actions: [
          if (release.htmlUrl.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: '在浏览器中打开',
              onPressed: () => _open(release.htmlUrl),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sell,
                          size: 22, color: AppColors.primaryRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(release.tagName,
                            style: theme.textTheme.titleLarge),
                      ),
                    ],
                  ),
                  if (release.name.isNotEmpty &&
                      release.name != release.tagName) ...[
                    const SizedBox(height: 6),
                    Text(release.name, style: theme.textTheme.titleMedium),
                  ],
                  const SizedBox(height: 8),
                  Text('发布于 ${formatDate(release.createdAt)}',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('发布说明', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  AppMarkdown(data: release.body),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('下载', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (release.zipballUrl.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _open(release.zipballUrl),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('下载 ZIP 源码'),
                    ),
                  if (release.zipballUrl.isNotEmpty &&
                      release.tarballUrl.isNotEmpty)
                    const SizedBox(height: 10),
                  if (release.tarballUrl.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _open(release.tarballUrl),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('下载 TAR 源码'),
                    ),
                  if (release.zipballUrl.isEmpty && release.tarballUrl.isEmpty)
                    Text('该版本没有提供源码附件', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
