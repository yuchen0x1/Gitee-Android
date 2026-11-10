import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// 全局配色，严格遵循 Gitee 品牌红与 Material 3 规范。
class AppColors {
  AppColors._();

  static const Color primaryRed = Color(0xFFE53935);
  static const Color primaryLight = Color(0xFFFF5252);
  static const Color primaryDark = Color(0xFFB71C1C);
  static const Color neonGlow = Color(0xFFFF4081);

  static const Color bgPage = Color(0xFFF0F4F8);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color divider = Color(0xFFE2E8F0);

  static const Color starColor = Color(0xFFFFB800);
  static const Color success = Color(0xFF10B981);
  static const Color closed = Color(0xFF64748B);

  /// 语义色：文件夹图标、已合并的 PR。
  static const Color folderIcon = Color(0xFFFFB800);
  static const Color merged = Color(0xFF8B5CF6);

  /// 编程语言对应色值，未知语言统一使用灰色。
  static Color languageColor(String? language) {
    const map = <String, Color>{
      'Dart': Color(0xFF00B4AB),
      'JavaScript': Color(0xFFF1E05A),
      'Python': Color(0xFF3572A5),
      'Java': Color(0xFFB07219),
      'Go': Color(0xFF00ADD8),
      'C': Color(0xFF555555),
      'C++': Color(0xFFF34B7D),
      'C#': Color(0xFF178600),
      'Swift': Color(0xFFFFAC45),
      'Kotlin': Color(0xFFA97BFF),
      'TypeScript': Color(0xFF2B7489),
      'PHP': Color(0xFF4F5D95),
      'Ruby': Color(0xFF701516),
      'Rust': Color(0xFFDEA584),
      'Vue': Color(0xFF41B883),
      'HTML': Color(0xFFE34C26),
      'CSS': Color(0xFF563D7C),
      'Shell': Color(0xFF89E051),
    };
    return map[language] ?? const Color(0xFF9CA3AF);
  }
}

/// Theme-aware semantic foreground colors for supporting text and icons.
extension AppThemeContext on BuildContext {
  Color get mutedForeground => Theme.of(this).colorScheme.outline;
  Color get secondaryForeground => Theme.of(this).colorScheme.onSurfaceVariant;
}

// ---------- 主题色映射 ----------

class _Palette {
  const _Palette({
    required this.scaffold,
    required this.card,
    required this.foreground,
    required this.titleColor,
    required this.bodyColor,
    required this.captionColor,
    required this.divider,
    required this.inputFill,
    required this.navLabel,
    required this.tabUnselected,
    required this.tabIndicator,
    required this.outlinedFg,
    required this.outlinedBorder,
  });

  final Color scaffold;
  final Color card;
  final Color foreground;
  final Color titleColor;
  final Color bodyColor;
  final Color captionColor;
  final Color divider;
  final Color inputFill;
  final Color navLabel;
  final Color tabUnselected;
  final Color tabIndicator;
  final Color outlinedFg;
  final Color outlinedBorder;
}

const _light = _Palette(
  scaffold: AppColors.bgPage,
  card: AppColors.bgCard,
  foreground: AppColors.textPrimary,
  titleColor: AppColors.textPrimary,
  bodyColor: AppColors.textSecondary,
  captionColor: AppColors.textTertiary,
  divider: AppColors.divider,
  inputFill: Color(0xB8FFFFFF),
  navLabel: AppColors.textPrimary,
  tabUnselected: AppColors.textTertiary,
  tabIndicator: AppColors.primaryRed,
  outlinedFg: AppColors.textPrimary,
  outlinedBorder: AppColors.divider,
);

const _dark = _Palette(
  scaffold: Color(0xFF0D1117), // GitHub / Cyberpunk 深空暗黑
  card: Color(0xFF161B22), // 科技感微高亮暗夜面板色
  foreground: Color(0xFFE6EDF3),
  titleColor: Color(0xFFF0F6FC),
  bodyColor: Color(0xFF8B949E),
  captionColor: Color(0xFF6E7681),
  divider: Color(0xFF30363D),
  inputFill: Color(0x1F8B949E),
  navLabel: Color(0xFFC9D1D9),
  tabUnselected: Color(0xFF8B949E),
  tabIndicator: Color(0xFFFF5252), // 极光科技红
  outlinedFg: Color(0xFFC9D1D9),
  outlinedBorder: Color(0xFF30363D),
);

// ---------- 构建主题 ----------

ThemeData buildLightTheme() => _buildTheme(Brightness.light, _light);
ThemeData buildDarkTheme() => _buildTheme(Brightness.dark, _dark);

ThemeData _buildTheme(Brightness brightness, _Palette p) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryRed,
      brightness: brightness,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: p.scaffold,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: p.foreground,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: p.foreground,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: p.card,
      shadowColor:
          brightness == Brightness.light ? Colors.black12 : Colors.black45,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: p.divider,
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: AppColors.primaryRed
          .withValues(alpha: brightness == Brightness.light ? 0.12 : 0.2),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.navLabel),
      ),
      iconTheme: const WidgetStatePropertyAll(IconThemeData(size: 24)),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: p.tabIndicator,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(width: 3, color: p.tabIndicator),
        borderRadius: const BorderRadius.all(Radius.circular(3)),
      ),
      labelColor: p.tabIndicator,
      unselectedLabelColor: p.tabUnselected,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: p.outlinedFg,
        side: BorderSide(color: p.outlinedBorder),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.inputFill,
      hintStyle: TextStyle(color: p.captionColor, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: p.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: p.tabIndicator, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColors.primaryRed),
      ),
    ),
    textTheme: base.textTheme.copyWith(
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: p.titleColor,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: p.titleColor,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: p.bodyColor),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: p.captionColor,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.card,
      contentTextStyle: TextStyle(color: p.foreground),
    ),
  );
}
