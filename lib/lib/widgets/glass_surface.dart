import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// 基于 liquid_glass_renderer 的液态玻璃面板（真折射 / 色散 / 高光）。
class TideGlassPanel extends StatelessWidget {
  const TideGlassPanel({
    super.key,
    required this.child,
    this.radius = 26,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.settings,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final LiquidGlassSettings? settings;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    final Widget panel = LiquidGlassLayer(
      settings:
          settings ?? LiquidGlassSettings.ios27Regular(brightness: brightness),
      defaultAppearance:
          LiquidGlassAppearance.ios27Regular(brightness: brightness),
      child: LiquidGlass(
        shape: LiquidRoundedSuperellipse(borderRadius: radius),
        child: Padding(padding: padding, child: child),
      ),
    );

    if (margin == null) return panel;
    return Padding(padding: margin!, child: panel);
  }
}
