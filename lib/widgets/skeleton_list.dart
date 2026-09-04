import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// 列表骨架屏，用于首次加载。
class SkeletonList extends StatelessWidget {
  final int itemCount;

  const SkeletonList({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF2A2A3D) : const Color(0xFFE8E9EF);
    final highlight = dark ? const Color(0xFF3A3A52) : const Color(0xFFF5F6FA);
    final cardColor = Theme.of(context).cardColor;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (_, __) => Container(
          height: 104,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF2A2A3D) : const Color(0xFFE8E9EF);
    final highlight = dark ? const Color(0xFF3A3A52) : const Color(0xFFF5F6FA);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
