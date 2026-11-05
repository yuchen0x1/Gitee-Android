import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A restrained glass surface for high-value UI layers.
/// [simple] 模式跳过 BackdropFilter，用半透明纯色 + 描边模拟质感，
/// 适合长列表逐项使用，避免每项一次模糊采样带来的性能开销。
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;
  final bool bordered;
  final Color? tint;
  final bool simple;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blur = 18,
    this.bordered = true,
    this.tint,
    this.simple = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = tint ??
        (isDark
            ? const Color(0xFF161B22).withValues(alpha: simple ? 0.92 : 0.82)
            : Colors.white.withValues(alpha: simple ? 0.90 : 0.78));
    final border = isDark
        ? const Color(0xFF30363D).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.88);

    final decoration = BoxDecoration(
      color: surface,
      borderRadius: borderRadius,
      border: bordered ? Border.all(color: border, width: 1.1) : null,
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.45)
              : const Color(0xFF64748B).withValues(alpha: 0.08),
          blurRadius: simple ? 12 : 24,
          offset: Offset(0, simple ? 4 : 10),
        ),
      ],
    );

    if (simple) {
      return DecoratedBox(
        decoration: decoration,
        child: Padding(padding: padding, child: child),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: decoration,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class GlassNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  const GlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color(0xFF000000).withValues(alpha: 0.6)
                  : AppColors.primaryRed.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          blur: 24,
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: destinations,
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 66,
          ),
        ),
      ),
    );
  }
}
