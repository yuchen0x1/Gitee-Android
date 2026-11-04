import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// 骨架屏形态：按列表内容的真实结构选择，替代统一的圆角块。
enum SkeletonVariant {
  /// 仓库卡：头像列 + 两行文字 + 底部统计行。
  repoCard,

  /// 用户行：圆形头像 + 两行文字。
  userTile,

  /// 提交/事件行：小头像 + 标题 + 一行描述。
  commitRow,

  /// Issue/PR 行：状态图标 + 两行文字。
  issueRow,

  /// 通用卡片块（默认）。
  generic,
}

Shimmer _shimmerOf(BuildContext context, Widget child) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final base = dark ? const Color(0xFF2A2A3D) : const Color(0xFFE8E9EF);
  final highlight = dark ? const Color(0xFF3A3A52) : const Color(0xFFF5F6FA);
  return Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: child);
}

/// 列表骨架屏，用于首次加载。
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final SkeletonVariant variant;

  const SkeletonList({
    super.key,
    this.itemCount = 6,
    this.variant = SkeletonVariant.generic,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    return _shimmerOf(
      context,
      ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _SkeletonRow(variant: variant, cardColor: cardColor),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  final SkeletonVariant variant;
  final Color cardColor;

  const _SkeletonRow({required this.variant, required this.cardColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final block = scheme.onSurface.withValues(alpha: 0.10);
    switch (variant) {
      case SkeletonVariant.repoCard:
        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration:
                        BoxDecoration(color: block, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  _Bar(width: 120, height: 13, color: block),
                ],
              ),
              const SizedBox(height: 10),
              _Bar(width: double.infinity, height: 12, color: block),
              const SizedBox(height: 8),
              _Bar(width: 180, height: 12, color: block),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Bar(width: 56, height: 10, color: block),
                  const SizedBox(width: 12),
                  _Bar(width: 56, height: 10, color: block),
                ],
              ),
            ],
          ),
        );
      case SkeletonVariant.userTile:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(color: block, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bar(width: 110, height: 13, color: block),
                    const SizedBox(height: 8),
                    _Bar(width: double.infinity, height: 11, color: block),
                  ],
                ),
              ),
            ],
          ),
        );
      case SkeletonVariant.commitRow:
      case SkeletonVariant.issueRow:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: block,
                  shape: variant == SkeletonVariant.commitRow
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                  borderRadius: variant == SkeletonVariant.issueRow
                      ? BorderRadius.circular(8)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bar(width: double.infinity, height: 13, color: block),
                    const SizedBox(height: 8),
                    _Bar(width: 140, height: 11, color: block),
                  ],
                ),
              ),
            ],
          ),
        );
      case SkeletonVariant.generic:
        return SizedBox(
          height: 104,
          child: Center(
            child: _Bar(width: double.infinity, height: 16, color: block),
          ),
        );
    }
  }
}

class _Bar extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _Bar({required this.width, required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

/// 单个骨架块，用于详情页中的局部加载。
class SkeletonBox extends StatelessWidget {
  final double height;

  const SkeletonBox({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return _shimmerOf(
      context,
      Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
