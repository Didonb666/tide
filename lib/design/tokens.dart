// lib/design/tokens.dart
//
// 设计 Token 的唯一来源：颜色、圆角、间距、字体层级、动效时长与曲线。
// 页面里出现硬编码的 Color / Duration / BorderRadius，一律视为 bug。
//
// 视觉取向：借鉴 Telegram 的"信息密度 + 极轻分隔"节奏，
// 但配色、圆角、字重层级全部原创，不使用任何第三方品牌资产。

import 'dart:ui' show FontFeature;

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
    canvas: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEDF0F4),
    hairline: Color(0xFFE3E7EC),
    ink: Color(0xFF0F141A),
    inkSecondary: Color(0xFF5B6674),
    inkTertiary: Color(0xFF8C97A6),
    accent: Color(0xFF0F8B7E),
    accentSoft: Color(0xFFE4F3F0),
    success: Color(0xFF1E9E6A),
    warning: Color(0xFFC77A16),
    danger: Color(0xFFD14343),
    info: Color(0xFF2A6FDB),
    scrim: Color(0x660A0F14),
  );

  static const TideColors dark = TideColors(
    canvas: Color(0xFF0B0F12),
    surface: Color(0xFF141A1F),
    surfaceMuted: Color(0xFF1B2329),
    hairline: Color(0xFF242E36),
    ink: Color(0xFFE9EEF3),
    inkSecondary: Color(0xFF9BA8B5),
    inkTertiary: Color(0xFF6E7B88),
    accent: Color(0xFF2FD3BE),
    accentSoft: Color(0xFF12312E),
    success: Color(0xFF3DD68C),
    warning: Color(0xFFE8A33D),
    danger: Color(0xFFF26D6D),
    info: Color(0xFF6AA0F5),
    scrim: Color(0x99000000),
  );

  /// 连接状态的语义色。不要在 widget 里写 switch。
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

/// 方便取色：`context.colors.accent`。
extension TideColorsX on BuildContext {
  TideColors get colors => Theme.of(this).extension<TideColors>()!;
}

// ---------------------------------------------------------------------------
// 圆角 / 间距
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
  static const BorderRadius rSheet =
      BorderRadius.vertical(top: Radius.circular(sheet));
}

abstract final class TideSpace {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;

  /// 页面左右安全边距。
  static const double page = 16;

  /// 会话列表行高（双行）。
  static const double row = 76;

  /// 头像直径。
  static const double avatar = 46;

  /// 分隔线左缩进，对齐头像右侧。
  static const double dividerInset = 78;
}

// ---------------------------------------------------------------------------
// 字体层级
// ---------------------------------------------------------------------------

abstract final class TideType {
  static const TextStyle display = TextStyle(
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
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

  /// 规则文本、IP、流量数字。等宽数字避免每秒跳动。
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

  /// 减速进场：绝大多数转场与展开。
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// 退场。
  static const Curve accelerate = Cubic(0.3, 0, 0.8, 0.15);
}

/// 尊重系统"减少动态效果"：所有时长都必须经过它。
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
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: c.accent,
        unselectedItemColor: c.inkTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
        selectedLabelStyle: TideType.caption,
        unselectedLabelStyle: TideType.caption,
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
