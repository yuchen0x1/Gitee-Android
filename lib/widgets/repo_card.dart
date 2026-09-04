import 'package:flutter/material.dart';
import '../models/repo.dart';
import '../pages/repo_detail_page.dart';
import '../theme/app_theme.dart';
import 'app_image.dart';
import 'glass_surface.dart';
import 'pressable_scale.dart';
import 'time_format.dart';

/// 通用仓库卡片，用于列表、搜索结果和个人仓库。
class RepoCard extends StatelessWidget {
  final Repo repo;

  const RepoCard({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressableScale(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                RepoDetailPage(owner: repo.ownerLogin, repo: repo.name),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassSurface(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppAvatar(url: repo.ownerAvatar, size: 40, radius: 8),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        repo.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (repo.isPrivate)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.closed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('私有',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.closed)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  repo.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (repo.language.isNotEmpty && repo.language != '未知') ...[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.languageColor(repo.language),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(repo.language, style: theme.textTheme.bodySmall),
                      const SizedBox(width: 16),
                    ],
                    const Icon(Icons.star_border,
                        size: 16, color: AppColors.starColor),
                    const SizedBox(width: 3),
                    Text(_count(repo.stars), style: theme.textTheme.bodySmall),
                    const SizedBox(width: 16),
                    const Icon(Icons.call_split,
                        size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 3),
                    Text(_count(repo.forks), style: theme.textTheme.bodySmall),
                    const Spacer(),
                    Text(
                      '更新于 ${formatRelativeTime(repo.updatedAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _count(int value) {
    if (value >= 10000) return '${(value / 10000).toStringAsFixed(1)}w';
    return value.toString();
  }
}
