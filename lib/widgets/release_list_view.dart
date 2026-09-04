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
              if (release.body.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  release.body.trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.arrow_forward,
                      size: 16, color: AppColors.textTertiary),
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
