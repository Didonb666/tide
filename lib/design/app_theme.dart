import 'package:flutter/material.dart';

import 'tokens.dart';

/// 主色调预设。
enum TideAccent {
  green(
    '极客绿',
    Color(0xFF0E9C8A),
    Color(0xFF2EE6C8),
    Color(0xFFE3F6F2),
    Color(0xFF0E2B29),
  ),
  blue(
    'Telegram 蓝',
    Color(0xFF2F80ED),
    Color(0xFF6AB2FF),
    Color(0xFFE7F0FE),
    Color(0xFF0D2440),
  ),
  purple(
    '暗夜紫',
    Color(0xFF7C5CFF),
    Color(0xFFA98BFF),
    Color(0xFFEFEAFF),
    Color(0xFF1B1433),
  );

  const TideAccent(
    this.label,
    this._lightAccent,
    this._darkAccent,
    this._lightSoft,
    this._darkSoft,
  );

  final String label;
  final Color _lightAccent;
  final Color _darkAccent;
  final Color _lightSoft;
  final Color _darkSoft;

  Color accentFor(Brightness brightness) =>
      brightness == Brightness.light ? _lightAccent : _darkAccent;

  Color softFor(Brightness brightness) =>
      brightness == Brightness.light ? _lightSoft : _darkSoft;
}

/// 在 TideTheme 上替换主色，并把 surface 做半透明，让全局背景透出来。
abstract final class AppTheme {
  /// 卡片 / 导航 / Tab 栏的底色透明度：越小越透。
  static const double darkSurfaceAlpha = 0.74;
  static const double lightSurfaceAlpha = 0.88;

  /// 卡片内次级底色（状态胶囊、输入框）的透明度。
  static const double darkMutedAlpha = 0.55;
  static const double lightMutedAlpha = 0.66;

  /// 底部弹窗要保持可读，所以接近不透明。
  static const double darkSheetAlpha = 0.96;
  static const double lightSheetAlpha = 0.98;

  static ThemeData light(TideAccent accent) =>
      _apply(TideTheme.light(), accent, Brightness.light);

  static ThemeData dark(TideAccent accent) =>
      _apply(TideTheme.dark(), accent, Brightness.dark);

  static ThemeData _apply(
    ThemeData base,
    TideAccent accent,
    Brightness brightness,
  ) {
    final bool isDark = brightness == Brightness.dark;

    final TideColors baseColors = base.extension<TideColors>()!;

    final TideColors colors = baseColors.copyWith(
      accent: accent.accentFor(brightness),
      accentSoft: accent.softFor(brightness),
      // 关键：把实底换成半透明底，背景就能透过所有用 surface 的控件。
      surface: baseColors.surface.withOpacity(
        isDark ? darkSurfaceAlpha : lightSurfaceAlpha,
      ),
      surfaceMuted: baseColors.surfaceMuted.withOpacity(
        isDark ? darkMutedAlpha : lightMutedAlpha,
      ),
    );

    final Color sheetColor = baseColors.surface.withOpacity(
      isDark ? darkSheetAlpha : lightSheetAlpha,
    );

    return base.copyWith(
      // 页面本身透明，背景层才看得到。
      scaffoldBackgroundColor: Colors.transparent,
      extensions: <ThemeExtension<dynamic>>[colors],
      // 注意：colorScheme 仍用不透明色，避免 Dialog / 菜单变半透明导致文字看不清。
      colorScheme: base.colorScheme.copyWith(
        primary: colors.accent,
        secondary: colors.accent,
        tertiary: colors.info,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: sheetColor,
        modalBackgroundColor: sheetColor,
      ),
      // surface 变半透明后，SnackBar 不能用它当文字色，改成固定浅色。
      snackBarTheme: base.snackBarTheme.copyWith(
        contentTextStyle: TideType.body.copyWith(
          color: const Color(0xFFF3F7FB),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
