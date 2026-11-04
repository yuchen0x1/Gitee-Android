import 'package:flutter/material.dart';

/// 代码高亮主题：亮色取自 GitHub Light，暗色取自 One Dark，
/// 按当前主题亮度选择，替换散落在页面里的硬编码色。
class CodeTheme {
  CodeTheme._();

  static const light = <String, Color>{
    'keyword': Color(0xFFB07219),
    'built_in': Color(0xFF3572A5),
    'type': Color(0xFF2B7489),
    'literal': Color(0xFF0086B3),
    'number': Color(0xFF0086B3),
    'string': Color(0xFF183691),
    'comment': Color(0xFF9CA3AF),
    'title': Color(0xFF6F42C1),
    'attr': Color(0xFF0086B3),
    'meta': Color(0xFF6B7280),
  };

  static const dark = <String, Color>{
    'keyword': Color(0xFFC678DD),
    'built_in': Color(0xFF61AFEF),
    'type': Color(0xFF61AFEF),
    'literal': Color(0xFFD19A66),
    'number': Color(0xFFD19A66),
    'string': Color(0xFF98C379),
    'comment': Color(0xFF7F848E),
    'title': Color(0xFF61AFEF),
    'attr': Color(0xFFE5C07B),
    'meta': Color(0xFFE5C07B),
  };

  /// 当前主题下的高亮色表。
  static Map<String, Color> colorsOf(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// 代码块背景（亮：浅灰蓝底；暗：One Dark 面板色）。
  static Color backgroundOf(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFF282C34)
          : const Color(0xFFF5F6FA);

  /// 代码块文字颜色。
  static Color textOf(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFFE4E4EF)
          : const Color(0xFF1A1A2E);
}
