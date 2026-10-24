// lib/design/tokens.dart
//
// 设计 Token 唯一来源：颜色、圆角、间距、字级、动效、模糊参数。
// 视觉基调：Telegram 的信息密度 + iOS 的半透明玻璃质感。
// 所有品牌元素（配色/圆角/图标用法）均为原创。

import 'dart:ui' show FontFeature;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// 颜色
// ---------------------------------------------------------------------------

@immutable
class TideColors extends ThemeExtension<TideColors> {
  const TideColors({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.hairline,
    required this.ink,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.scrim,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color hairline;
  final Color ink;
  final Color inkSecondary;
  final Color inkTertiary;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color scrim;

  static const TideColors light = TideColors(
    canvas: Color(0xFFF4F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEDF1F7),
    hairline: Color(0xFFE1E7EF),
    ink: Color(0xFF0B1117),
    inkSecondary: Color(0xFF5A6B7B),
    inkTertiary: Color(0xFF8A99A8),
    accent: Color(0xFF0E9C8A),
    accentSoft: Color(0xFFE3F6F2),
    success: Color(0xFF12B76A),
    warning: Color(0xFFD98A00),
    danger: Color(0xFFF04452),
    info: Color(0xFF2F80ED),
    scrim: Color(0x66000000),
  );

  static const TideColors dark = TideColors(
    canvas: Color(0xFF070A10),      // 深灰偏蓝
    surface: Color(0xFF0E141C),
    surfaceMuted: Color(0xFF151E28),
    hairline: Color(0xFF223040),
    ink: Color(0xFFEAF1F7),
    inkSecondary: Color(0xFF9FB0C0),
    inkTertiary: Color(0xFF6C7F91),
    accent: Color(0xFF2EE6C8),      // 高亮青绿
    accentSoft: Color(0xFF0E2B29),
    success: Color(0xFF22E06E),     // 极鲜亮绿
    warning: Color(0xFFFFB020),
    danger: Color(0xFFFF4D5E),      // 极鲜亮红
    info: Color(0xFF5AA8FF),
    scrim: Color(0x99000000),
  );

  Color status({
    required bool connected,
    required bool busy,
    required bool failed,
  }) {
    if (failed) return danger;
    if (connected) return success;
    if (busy) return warning;
    return inkTertiary;
  }

  /// 闪烁/高光用：把颜色提亮一点。
  Color glow(double t) => Color.lerp(this == TideColors.dark ? accent : accent, Colors.white, t.clamp(0.0, 1.0))!;

  @override
  TideColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? hairline,
    Color? ink,
    Color? inkSecondary,
    Color? inkTertiary,
    Color? accent,
    Color? accentSoft,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? scrim,
  }) {
    return TideColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      hairline: hairline ?? this.hairline,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkTertiary: inkTertiary ?? this.inkTertiary,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  TideColors lerp(ThemeExtension<TideColors>? other, double t) {
    if (other is! TideColors) return this;
    return TideColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkTertiary: Color.lerp(inkTertiary, other.inkTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// 方便取色：`context.colors.accent`
extension TideColorsX on BuildContext {
  TideColors get colors => Theme.of(this).extension<TideColors>()!;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ---------------------------------------------------------------------------
// 圆角 / 间距 / 模糊
// ---------------------------------------------------------------------------

abstract final class TideRadii {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double sheet = 28;
  static const double full = 999;

  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius rSheet = BorderRadius.vertical(top: Radius.circular(sheet));
}

abstract final class TideSpace {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;

  static const double page = 16;
  static const double row = 76;
  static const double avatar = 46;
  static const double dividerInset = 78;

  /// 底部玻璃导航栏高度（不含安全区），列表底部要留出这么多空间。
  static const double navBar = 64;
}

abstract final class TideBlur {
  /// 底部导航栏
  static const double nav = 24;

  /// 卡片 / 弹层
  static const double panel = 18;
}

// ---------------------------------------------------------------------------
// 字体层级
// ---------------------------------------------------------------------------

abstract final class TideType {
  static const TextStyle display = TextStyle(
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );

  static const TextStyle title = TextStyle(
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 17,
    height: 23 / 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 21 / 15,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle subhead = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static const TextStyle mono = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
}

// ---------------------------------------------------------------------------
// 动效
// ---------------------------------------------------------------------------

abstract final class TideMotion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration quick = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration large = Duration(milliseconds: 320);
  static const Duration sheetOut = Duration(milliseconds: 220);
  static const Duration pulse = Duration(milliseconds: 1800);
  static const Duration flow = Duration(milliseconds: 2600);
  static const Duration stagger = Duration(milliseconds: 460);
  static const int staggerStepMs = 55;

  static const Curve standard = Cubic(0.2, 0, 0, 1);
  static const Curve accelerate = Cubic(0.3, 0, 0.8, 0.15);
}

extension TideMotionX on BuildContext {
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  Duration motion(Duration duration) => reduceMotion ? Duration.zero : duration;
}

// ---------------------------------------------------------------------------
// ThemeData
// ---------------------------------------------------------------------------

abstract final class TideTheme {
  static ThemeData light() => _build(Brightness.light, TideColors.light);

  static ThemeData dark() => _build(Brightness.dark, TideColors.dark);

  static ThemeData _build(Brightness brightness, TideColors c) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
    ).copyWith(surface: c.surface, error: c.danger);

    final ThemeData base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[c],
      textTheme: base.textTheme.copyWith(
        displaySmall: TideType.display.copyWith(color: c.ink),
        headlineSmall: TideType.title.copyWith(color: c.ink),
        titleMedium: TideType.headline.copyWith(color: c.ink),
        titleSmall: TideType.subhead.copyWith(
          color: c.inkSecondary,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TideType.body.copyWith(color: c.ink),
        bodySmall: TideType.subhead.copyWith(color: c.inkSecondary),
        labelSmall: TideType.caption.copyWith(color: c.inkTertiary),
        labelMedium: TideType.caption.copyWith(
          color: c.inkSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
      dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        foregroundColor: c.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TideType.title.copyWith(color: c.ink, fontSize: 20),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: TideRadii.rSheet),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: TideType.body.copyWith(color: c.surface),
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}
