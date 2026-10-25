import 'dart:math' as math;
import 'dart:ui' show FilterQuality, ImageFilter, TileMode;

import 'package:flutter/material.dart';

import '../core/settings_controller.dart';
import '../design/tokens.dart';

enum LiquidEffectLevel { full, static }

class LiquidGlassContainer extends StatefulWidget {
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

  /// 传 null 表示跟随全局「玻璃模糊」设置。
  final double? sigma;

  /// 传 null 表示跟随全局「高光强度」设置。
  final double? highlight;

  final double borderWidth;
  final Color? tint;
  final LiquidEffectLevel effect;

  @override
  State<LiquidGlassContainer> createState() => _LiquidGlassContainerState();
}

class _LiquidGlassContainerState extends State<LiquidGlassContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  double get _sigma =>
      (widget.sigma ?? SettingsScope.maybeOf(context)?.glassBlur ?? 18)
          .clamp(0.0, 30.0);

  double get _highlight =>
      (widget.highlight ?? SettingsScope.maybeOf(context)?.glassHighlight ?? 1.0)
          .clamp(0.0, 1.0);

  bool get _animated {
    if (widget.effect != LiquidEffectLevel.full) return false;
    if (_sigma <= 0) return false;
    final bool reduce = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    return !reduce;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _fillColors(bool dark) {
    if (widget.tint != null) {
      return <Color>[
        widget.tint!.withOpacity(dark ? 0.46 : 0.55),
        widget.tint!.withOpacity(dark ? 0.28 : 0.38),
      ];
    }
    return dark
        ? const <Color>[Color(0x66000000), Color(0x3D000000)]
        : const <Color>[Color(0xA6FFFFFF), Color(0x73FFFFFF)];
  }

  Widget _buildContent(double t, Widget child) {
    final bool dark = context.isDark;
    final bool animated = _animated;
    final double sigma = _sigma;
    final double highlight = _highlight;
    final double radius = widget.radius;
    final double innerRadius = (radius - widget.borderWidth).clamp(0.0, radius);

    final Widget fill = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(innerRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _fillColors(dark),
        ),
      ),
      child: child,
    );

    final ImageFilter filter = animated
        ? ImageFilter.compose(
            outer: ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma,
              tileMode: TileMode.decal,
            ),
            inner: ImageFilter.matrix(
              (Matrix4.identity()
                    ..scale(1.003, 1.003, 1.0)
                    ..translate(-0.001, -0.001, 0.0))
                  .storage,
              filterQuality: FilterQuality.medium,
            ),
          )
        : ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.decal,
          );

    // 关键修复：模糊层用【静态】圆角剪裁。
    // 之前每帧重建贝塞尔 ClipPath，滚动时图层反复失效导致模糊消失。
    final Widget glass = ClipPath(
      clipper: _GlassClipper(radius),
      child: sigma > 0 ? BackdropFilter(filter: filter, child: fill) : fill,
    );

    return RepaintBoundary(
      child: Stack(
        children: <Widget>[
          glass,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _LiquidEdgePainter(
                  radius: radius,
                  t: t,
                  animate: animated,
                  dark: dark,
                  borderWidth: widget.borderWidth,
                  highlight: highlight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_animated && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_animated && _controller.isAnimating) {
      _controller.stop();
    }

    final Widget content = AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        return _buildContent(_animated ? _controller.value : 0.0, child!);
      },
    );

    if (widget.margin == null) return content;
    return Padding(padding: widget.margin!, child: content);
  }
}

const List<Shadow> glassTextShadow = <Shadow>[
  Shadow(color: Color(0x73000000), blurRadius: 8, offset: Offset(0, 1)),
];

abstract final class LiquidGlassPath {
  static Path build(Size size, double radius, double t, bool animate) {
    if (size.isEmpty) return Path();

    final double r = radius.clamp(4.0, size.shortestSide / 2);

    if (!animate) {
      return Path()
        ..addRRect(
          RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)),
        );
    }

    final double w = size.width;
    final double h = size.height;
    const double amp = 1.4;

    double wave(int i) => amp * math.sin(t * 2 * math.pi + i * 1.7);

    final double rTop = (r + wave(0)).clamp(4.0, h / 2);
    final double rRight = (r + wave(1)).clamp(4.0, w / 2);
    final double rBottom = (r + wave(2)).clamp(4.0, h / 2);
    final double rLeft = (r + wave(3)).clamp(4.0, w / 2);

    return Path()
      ..moveTo(rLeft, 0)
      ..lineTo(w - rTop, 0)
      ..cubicTo(w - rTop * 0.4, 0, w, rTop * 0.4, w, rRight)
      ..lineTo(w, h - rRight)
      ..cubicTo(w, h - rRight * 0.4, w - rBottom * 0.4, h, w - rBottom, h)
      ..lineTo(rBottom, h)
      ..cubicTo(rBottom * 0.4, h, 0, h - rBottom * 0.4, 0, h - rLeft)
      ..lineTo(0, rLeft)
      ..cubicTo(0, rLeft * 0.4, rLeft * 0.4, 0, rLeft, 0)
      ..close();
  }
}

/// 静态圆角剪裁：保证 BackdropFilter 图层稳定，滚动不掉模糊。
class _GlassClipper extends CustomClipper<Path> {
  const _GlassClipper(this.radius);

  final double radius;

  @override
  Path getClip(Size size) => LiquidGlassPath.build(size, radius, 0, false);

  @override
  bool shouldReclip(covariant _GlassClipper oldClipper) =>
      oldClipper.radius != radius;
}

class _LiquidEdgePainter extends CustomPainter {
  _LiquidEdgePainter({
    required this.radius,
    required this.t,
    required this.animate,
    required this.dark,
    required this.borderWidth,
    required this.highlight,
  });

  final double radius;
  final double t;
  final bool animate;
  final bool dark;
  final double borderWidth;
  final double highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path =
        LiquidGlassPath.build(size, radius, animate ? t : 0.0, animate);
    final Rect rect = Offset.zero & size;
    final double h = highlight.clamp(0.0, 1.0);

    canvas.drawShadow(
      path,
      Colors.black.withOpacity(dark ? 0.48 : 0.18),
      24,
      true,
    );

    if (animate) {
      final Paint red = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFFFF3B30).withOpacity(0.18 * h)
        ..blendMode = BlendMode.plus;
      final Paint blue = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFF2B7FFF).withOpacity(0.18 * h)
        ..blendMode = BlendMode.plus;

      canvas.drawPath(path.shift(const Offset(-1.4, -0.4)), red);
      canvas.drawPath(path.shift(const Offset(1.4, 0.4)), blue);
    }

    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.fromRGBO(255, 255, 255, (0.95 * h).clamp(0.0, 1.0)),
          Color.fromRGBO(255, 255, 255, (0.38 * h).clamp(0.0, 1.0)),
          Color.fromRGBO(255, 255, 255, (0.10 * h).clamp(0.0, 1.0)),
          Color.fromRGBO(255, 255, 255, (0.04 * h).clamp(0.0, 1.0)),
        ],
        stops: const <double>[0.0, 0.28, 0.75, 1.0],
      ).createShader(rect);
    canvas.drawPath(path, border);

    final Paint bottomGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0x00FFFFFF),
          const Color(0x00FFFFFF),
          Color.fromRGBO(255, 255, 255, (0.18 * h).clamp(0.0, 1.0)),
          Color.fromRGBO(255, 255, 255, (0.08 * h).clamp(0.0, 1.0)),
        ],
        stops: const <double>[0.0, 0.72, 0.92, 1.0],
      ).createShader(rect);
    canvas.drawPath(path, bottomGlow);

    final Paint innerGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.white.withOpacity((animate ? 0.10 : 0.07) * h)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, innerGlow);
  }

  @override
  bool shouldRepaint(covariant _LiquidEdgePainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.dark != dark ||
        oldDelegate.radius != radius ||
        oldDelegate.animate != animate ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.highlight != highlight;
  }
}
