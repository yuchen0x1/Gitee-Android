import 'package:flutter/material.dart';
import '../models/release.dart';
import '../theme/app_theme.dart';
import 'paged_list_view.dart';
import 'time_format.dart';

/// 暂无版本发布分页列表，点击通过回调进入详情页。
class ReleaseListView extends StatelessWidget {
  final Future<List<Release>> Function(int page) loadPage;
  final void Function(Release item) onTap;

  const ReleaseListView({
    super.key,
    required this.loadPage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PagedListView<Release>(
      loadPage: loadPage,
      itemBuilder: (context, item) => _ReleaseCard(
        release: item,
        onTap: () => onTap(item),
      ),
      emptyIcon: Icons.new_releases_outlined,
      emptyTitle: '暂无版本发布',
      emptySubtitle: '该仓库还没有发布过版本',
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  final Release release;
  final VoidCallback onTap;

  const _ReleaseCard({required this.release, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sell, size: 18, color: AppColors.primaryRed),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      release.tagName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text(formatRelativeTime(release.createdAt),
                      style: theme.textTheme.bodySmall),
                ],
              ),
              if (release.name.isNotEmpty &&
                  release.name != release.tagName) ...[
                const SizedBox(height: 4),
                Text(release.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall),
              ],
              if (_plainSummary(release.body).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _plainSummary(release.body),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.arrow_forward,
                      size: 16, color: context.mutedForeground),
                  const SizedBox(width: 4),
                  Text('查看发布说明', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 把 Release 正文的 Markdown 粗略压成纯文本，供列表摘要预览使用。
///
/// 列表里没有渲染 Markdown 的能力，直接展示原文会暴露 `###`、`**` 等标记，
/// 这里只做去标记处理，不追求完整解析（完整渲染在发布详情页）。
String _plainSummary(String body) {
  var text = body
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '') // 图片
      .replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1') // 链接保留文字
      .replaceAll(RegExp(r'<[^>]+>'), '') // HTML 标签
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '') // 标题
      .replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '') // 引用
      .replaceAll(
          RegExp(r'^\s{0,3}([-*+]|\d+\.)\s+', multiLine: true), '') // 列表
      .replaceAll(
          RegExp(r'^\s{0,3}([-*_]\s*){3,}$', multiLine: true), '') // 分隔线
      .replaceAll(RegExp(r'(\*\*|__|\*|_|~~|`)'), '') // 强调与行内代码
      .replaceAll(RegExp(r'[ \t]+\n'), '\n') // 行尾空白
      .replaceAll(RegExp(r'\n{2,}'), '\n'); // 压缩空行
  return text.trim();
}
