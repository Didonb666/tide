import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// full  = 真折射（LiquidGlass）
/// static = FakeGlass（无折射，省一点）
enum LiquidEffectLevel { full, static }

const List<Shadow> glassTextShadow = <Shadow>[
  Shadow(color: Color(0x73000000), blurRadius: 8, offset: Offset(0, 1)),
];

/// 全局玻璃容器：内部改用 liquid_glass_renderer 渲染真实折射玻璃。
///
/// 构造参数保持与旧版完全一致（radius / padding / margin / sigma /
/// highlight / borderWidth / tint / effect），所以所有旧调用点
/// 不需要改一行就能升级成真玻璃。
class LiquidGlassContainer extends StatelessWidget {
  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.sigma,
    this.highlight,
    this.borderWidth = 1.2,
    this.tint,
    this.effect = LiquidEffectLevel.full,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// 映射到 liquid_glass_renderer 的 frost（背景模糊）。
  final double? sigma;

  /// 映射到 glint（边缘高光强度）。
  final double? highlight;

  /// 预留给后续描边定制，当前由渲染器自动生成。
  final double borderWidth;

  /// 预留：着色需要 appearance，接入见下方说明。
  final Color? tint;

  final LiquidEffectLevel effect;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    LiquidGlassSettings settings =
        LiquidGlassSettings.ios27Regular(brightness: brightness);

    final double? frost = sigma;
    if (frost != null && frost > 0) {
      settings = settings.copyWith(frost: frost);
    }

    final double? glint = highlight;
    if (glint != null) {
      settings = settings.copyWith(highlight: glint.clamp(0.0, 1.0));
    }

    final Widget panel = LiquidGlassLayer(
      settings: settings,
      defaultAppearance:
          LiquidGlassAppearance.ios27Regular(brightness: brightness),
      fake: effect == LiquidEffectLevel.static,
      child: LiquidGlass(
        shape: LiquidRoundedSuperellipse(borderRadius: radius),
        child: Padding(padding: padding, child: child),
      ),
    );

    if (margin == null) return panel;
    return Padding(padding: margin!, child: panel);
  }
}
