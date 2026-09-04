import "package:flutter/material.dart";
import "../theme/app_theme.dart";

class AppBadge extends StatelessWidget {
  final int count;
  final double size;
  final Color? color;
  const AppBadge({super.key, required this.count, this.size = 18, this.color});
  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final bg = color ?? AppColors.primaryRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size)),
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      child: Center(
          child: Text(count > 99 ? "99+" : "$count",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.65,
                  fontWeight: FontWeight.w700))),
    );
  }
}
