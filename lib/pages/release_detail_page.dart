import 'package:flutter/material.dart';
import '../api/gitee_api.dart';
import '../models/release.dart';
import '../models/release_attach_file.dart';
import '../theme/app_theme.dart';
import '../utils/launch_url.dart';
import '../widgets/app_markdown.dart';
import '../widgets/time_format.dart';

/// Release 详情页：发布说明、附件与源码包下载入口。
/// [owner]/[repo] 提供时加载 Gitee 附件（如应用更新日志等非 Gitee 仓库场景可不传）。
class ReleaseDetailPage extends StatefulWidget {
  final Release release;
  final String? owner;
  final String? repo;

  const ReleaseDetailPage({
    super.key,
    required this.release,
    this.owner,
    this.repo,
  });

  @override
  State<ReleaseDetailPage> createState() => _ReleaseDetailPageState();
}

class _ReleaseDetailPageState extends State<ReleaseDetailPage> {
  List<ReleaseAttachFile> _attachFiles = [];
  bool _attachLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttachFiles();
  }

  /// 附件属于增强信息，失败时保持空列表，不影响主体内容。
  Future<void> _loadAttachFiles() async {
    final owner = widget.owner;
    final repo = widget.repo;
    if (owner == null ||
        owner.isEmpty ||
        repo == null ||
        repo.isEmpty ||
        widget.release.id <= 0) {
      if (mounted) setState(() => _attachLoading = false);
      return;
    }
    setState(() => _attachLoading = true);
    try {
      final files = await GiteeApi.getReleaseAttachFiles(
        owner,
        repo,
        widget.release.id,
      );
      if (!mounted) return;
      setState(() {
        _attachFiles = files;
        _attachLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _attachLoading = false);
    }
  }

  Future<void> _open(String url) async {
    await launchExternalUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final release = widget.release;
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
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('附件 (${_attachFiles.length})',
                            style: theme.textTheme.titleMedium),
                      ),
                      IconButton(
                        tooltip: '刷新附件',
                        onPressed: _loadAttachFiles,
                        icon: const Icon(Icons.refresh, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_attachLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (_attachFiles.isEmpty)
                    Text('该版本暂无上传附件', style: theme.textTheme.bodySmall)
                  else
                    ..._attachFiles.map(
                      (file) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.attachment_outlined),
                        title: Text(file.name, overflow: TextOverflow.ellipsis),
                        subtitle: file.sizeText.isEmpty
                            ? null
                            : Text('大小 ${file.sizeText}',
                                style: theme.textTheme.bodySmall),
                        trailing: const Icon(Icons.download_outlined),
                        onTap: () => _open(file.downloadUrl),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
