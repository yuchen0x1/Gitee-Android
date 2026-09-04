import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 统一头像组件：占位图 → 加载中 → 成功/失败。
class AppAvatar extends StatelessWidget {
  final String url;
  final double size;
  final double radius;

  const AppAvatar({
    super.key,
    required this.url,
    this.size = 40,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    if (url.trim().isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: size,
          height: size,
          color: bg,
          child: Icon(Icons.person,
              size: size * 0.5, color: Theme.of(context).colorScheme.outline),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: size,
          height: size,
          color: bg,
          child: Icon(Icons.person,
              size: size * 0.5, color: Theme.of(context).colorScheme.outline),
        ),
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
          color: bg,
          child: Icon(Icons.person_off,
              size: size * 0.5, color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
}
