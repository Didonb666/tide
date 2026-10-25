import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// 全 App 玻璃质感的基石：高斯模糊 + 极低透明底色 + 渐变高光边框。
class LiquidGlassContainer extends StatelessWidget {
  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.sigma = 18,
    this.borderWidth = 1.2,
    this.tint,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// 模糊强度。列表卡片建议传 0（只保留半透明 + 边框），避免多次离屏采样。
  final double sigma;
  final double borderWidth;

  /// 可选着色，用于连接按钮、状态卡等主题色玻璃。
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final double innerRadius = (radius - borderWidth).clamp(0.0, radius);

    final List<Color> borderColors = dark
        ? const <Color>[
            Color(0x73FFFFFF),
            Color(0x1FFFFFFF),
            Color(0x0DFFFFFF),
            Color(0x40000000),
          ]
        : const <Color>[
            Color(0xE6FFFFFF),
            Color(0x80FFFFFF),
            Color(0x14000000),
            Color(0x26000000),
          ];

    final List<Color> fillColors;
    if (tint != null) {
      fillColors = <Color>[
        tint!.withOpacity(dark ? 0.46 : 0.55),
        tint!.withOpacity(dark ? 0.28 : 0.38),
      ];
    } else {
      fillColors = dark
          ? const <Color>[Color(0x66000000), Color(0x3D000000)]
          : const <Color>[Color(0xA6FFFFFF), Color(0x73FFFFFF)];
    }

    final Widget content = Container(
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: borderColors,
          stops: const <double>[0.0, 0.35, 0.7, 1.0],
        ),
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(innerRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: fillColors,
          ),
        ),
        child: child,
      ),
    );

    final Widget clipped = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: sigma > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: content,
            )
          : content,
    );

    final Widget wrapped = RepaintBoundary(child: clipped);
    return margin == null ? wrapped : Padding(padding: margin!, child: wrapped);
  }
}

/// 玻璃上的文字阴影，防止亮色壁纸下看不清。
const List<Shadow> glassTextShadow = <Shadow>[
  Shadow(color: Color(0x73000000), blurRadius: 8, offset: Offset(0, 1)),
];
