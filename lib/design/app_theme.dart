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

/// 在现有 TideTheme 上替换主色，并让 Scaffold 透明以露出全局背景层。
abstract final class AppTheme {
  static ThemeData light(TideAccent accent) =>
      _apply(TideTheme.light(), accent, Brightness.light);

  static ThemeData dark(TideAccent accent) =>
      _apply(TideTheme.dark(), accent, Brightness.dark);

  static ThemeData _apply(
    ThemeData base,
    TideAccent accent,
    Brightness brightness,
  ) {
    final TideColors colors = base.extension<TideColors>()!.copyWith(
      accent: accent.accentFor(brightness),
      accentSoft: accent.softFor(brightness),
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
    );
  }
}
