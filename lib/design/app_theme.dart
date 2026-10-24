import 'package:flutter/material.dart';

import 'tokens.dart';

/// 预设主色。seed 用于任意颜色计算，*Accent 用于预设圆点展示。
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
    '赛博紫',
    Color(0xFF7C5CFF),
    Color(0xFFA98BFF),
    Color(0xFFEFEAFF),
    Color(0xFF1B1433),
  ),
  orange(
    '落日橙',
    Color(0xFFF2700A),
    Color(0xFFFFA45C),
    Color(0xFFFFF0E2),
    Color(0xFF3A2008),
  ),
  rose(
    '霓虹玫红',
    Color(0xFFE0356B),
    Color(0xFFFF7BA8),
    Color(0xFFFFE8EF),
    Color(0xFF3A0F1D),
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

  /// 统一用"浅色版"作为种子，深色模式由 AppTheme 自动提亮。
  Color get seed => _lightAccent;

  Color accentFor(Brightness brightness) =>
      brightness == Brightness.light ? _lightAccent : _darkAccent;

  Color softFor(Brightness brightness) =>
      brightness == Brightness.light ? _lightSoft : _darkSoft;
}

abstract final class AppTheme {
  static const double darkSurfaceAlpha = 0.74;
  static const double lightSurfaceAlpha = 0.88;
  static const double darkMutedAlpha = 0.55;
  static const double lightMutedAlpha = 0.66;
  static const double darkSheetAlpha = 0.96;
  static const double lightSheetAlpha = 0.98;

  static ThemeData light(Color seed) =>
      _apply(TideTheme.light(), seed, Brightness.light);

  static ThemeData dark(Color seed) =>
      _apply(TideTheme.dark(), seed, Brightness.dark);

  /// 深色模式下把用户给的颜色提亮，保证在暗背景上够醒目。
  static Color resolveAccent(Color seed, Brightness brightness) {
    if (brightness == Brightness.light) return seed;
    final HSLColor hsl = HSLColor.fromColor(seed);
    return hsl
        .withLightness((hsl.lightness + 0.16).clamp(0.0, 0.92))
        .withSaturation((hsl.saturation * 0.98).clamp(0.0, 1.0))
        .toColor();
  }

  static ThemeData _apply(
    ThemeData base,
    Color seed,
    Brightness brightness,
  ) {
    final bool isDark = brightness == Brightness.dark;
    final TideColors baseColors = base.extension<TideColors>()!;
    final Color accent = resolveAccent(seed, brightness);

    final TideColors colors = baseColors.copyWith(
      accent: accent,
      accentSoft: Color.alphaBlend(
        accent.withOpacity(isDark ? 0.18 : 0.14),
        baseColors.surface,
      ),
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
      scaffoldBackgroundColor: Colors.transparent,
      extensions: <ThemeExtension<dynamic>>[colors],
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
      snackBarTheme: base.snackBarTheme.copyWith(
        contentTextStyle: TideType.body.copyWith(
          color: const Color(0xFFF3F7FB),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
