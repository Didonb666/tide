import 'dart:math' as math;
import 'dart:ui' show FilterQuality, ImageFilter;

import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// 特效等级：
/// - full   ：流体形变 + 折射 + 色散（主控区：首页大卡、底部导航）
/// - static ：静态磨砂（列表卡片、设置分组，省电）
enum LiquidEffectLevel { full, static }

/// 真·液态玻璃容器。
class LiquidGlassContainer extends StatefulWidget {
  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.sigma = 18,
    this.borderWidth = 1.2,
    this.tint,
    this.effect = LiquidEffectLevel.full,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// 模糊强度。列表卡片传 0（组件会自动降级为 static）。
  final double sigma;
  final double borderWidth;

  /// 可选着色（连接按钮、激活卡片等）。
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

  bool get _animated {
    if (widget.effect != LiquidEffectLevel.full) return false;
    if (widget.sigma <= 0) return false;
    final bool reduce = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    return !reduce;
  }

  @override
  void initState() {
    super.initState();
    if (_animated) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant LiquidGlassContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_animated && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_animated && _controller.isAnimating) {
      _controller.stop();
    }
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
              sigmaX: widget.sigma,
              sigmaY: widget.sigma,
            ),
            inner: ImageFilter.matrix(
              (Matrix4.identity()
                    ..scale(1.003, 1.003, 1.0)
                    ..translate(-0.001, -0.001, 0.0))
                  .storage,
              filterQuality: FilterQuality.medium,
            ),
          )
        : ImageFilter.blur(sigmaX: widget.sigma, sigmaY: widget.sigma);

    final Widget glass = ClipPath(
      clipper: _LiquidClipper(
        radius: radius,
        t: t,
        animate: animated,
      ),
      child: widget.sigma > 0
          ? BackdropFilter(filter: filter, child: fill)
          : fill,
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

/// 玻璃上的文字阴影，防止亮色壁纸下看不清。
const List<Shadow> glassTextShadow = <Shadow>[
  Shadow(color: Color(0x73000000), blurRadius: 8, offset: Offset(0, 1)),
];

// ---------------------------------------------------------------------------
// 流体贝塞尔路径
// ---------------------------------------------------------------------------

abstract final class LiquidGlassPath {
  /// 生成玻璃轮廓。四个角的半径各自以不同相位轻微起伏，
  /// 幅度约 1.4px，肉眼可见“融化感”但不至于显得在抖动。
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

class _LiquidClipper extends CustomClipper<Path> {
  const _LiquidClipper({
    required this.radius,
    required this.t,
    required this.animate,
  });

  final double radius;
  final double t;
  final bool animate;

  @override
  Path getClip(Size size) =>
      LiquidGlassPath.build(size, radius, animate ? t : 0.0, animate);

  @override
  bool shouldReclip(covariant _LiquidClipper oldClipper) {
    return oldClipper.t != t ||
        oldClipper.radius != radius ||
        oldClipper.animate != animate;
  }
}

// ---------------------------------------------------------------------------
// 边缘高光 / 色散 / 内发光
// ---------------------------------------------------------------------------

class _LiquidEdgePainter extends CustomPainter {
  _LiquidEdgePainter({
    required this.radius,
    required this.t,
    required this.animate,
    required this.dark,
    required this.borderWidth,
  });

  final double radius;
  final double t;
  final bool animate;
  final bool dark;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path =
        LiquidGlassPath.build(size, radius, animate ? t : 0.0, animate);
    final Rect rect = Offset.zero & size;

    // 1. 外围环境阴影（玻璃悬浮感）
    canvas.drawShadow(
      path,
      Colors.black.withOpacity(dark ? 0.48 : 0.18),
      24,
      true,
    );

    if (animate) {
      // 2. 色散反光：红/蓝各偏移 1.4px，plus 混合叠加
      final Paint red = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0x2EFF3B30)
        ..blendMode = BlendMode.plus;
      final Paint blue = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0x2E2B7FFF)
        ..blendMode = BlendMode.plus;

      canvas.drawPath(path.shift(const Offset(-1.4, -0.4)), red);
      canvas.drawPath(path.shift(const Offset(1.4, 0.4)), blue);
    }

    // 3. 主边框：顶部锐利白光 → 向下逐渐消失
    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xF2FFFFFF),
          Color(0x61FFFFFF),
          Color(0x1AFFFFFF),
          Color(0x0AFFFFFF),
        ],
        stops: <double>[0.0, 0.28, 0.75, 1.0],
      ).createShader(rect);
    canvas.drawPath(path, border);

    // 4. 底部微弱辉光（光源从上方打下来，底部只留一丝反光）
    final Paint bottomGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0x00FFFFFF),
          Color(0x00FFFFFF),
          Color(0x2EFFFFFF),
          Color(0x14FFFFFF),
        ],
        stops: <double>[0.0, 0.72, 0.92, 1.0],
      ).createShader(rect);
    canvas.drawPath(path, bottomGlow);

    // 5. 内圈发光（模拟 inset 内阴影：模糊描边向内侧晕开）
    final Paint innerGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.white.withOpacity(animate ? 0.10 : 0.07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, innerGlow);
  }

  @override
  bool shouldRepaint(covariant _LiquidEdgePainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.dark != dark ||
        oldDelegate.radius != radius ||
        oldDelegate.animate != animate ||
        oldDelegate.borderWidth != borderWidth;
  }
}
