import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/settings_controller.dart';
import '../design/tokens.dart';

/// 顶层雪花/粒子层。全部参数从 SettingsController 读取：
/// 图片（可选）、数量、大小、速度。IgnorePointer 不挡点击。
class SnowOverlay extends StatefulWidget {
  const SnowOverlay({super.key});

  @override
  State<SnowOverlay> createState() => _SnowOverlayState();
}

class _SnowOverlayState extends State<SnowOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  );

  ui.Image? _image;
  String? _imagePath;
  int _count = -1;
  List<_Snow> _snow = <_Snow>[];

  @override
  void initState() {
    super.initState();
    final bool reduce = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (!reduce) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _maybeLoadImage(String? path) {
    if (path == _imagePath) return;
    _imagePath = path;
    _image = null;

    if (path == null || path.isEmpty) return;
    final File file = File(path);
    if (!file.existsSync()) return;

    file.readAsBytes().then((List<int> bytes) {
      return ui.decodeImageFromList(bytes);
    }).then((ui.Image img) {
      if (mounted && _imagePath == path) {
        setState(() => _image = img);
      }
    }).catchError((Object _) {});
  }

  List<_Snow> _build(int count) {
    final math.Random random = math.Random(20261024);
    return List<_Snow>.generate(count, (int index) {
      return _Snow(
        x: random.nextDouble(),
        offset: random.nextDouble(),
        speed: 0.35 + random.nextDouble() * 0.55,
        size: 1.2 + random.nextDouble() * 2.2,
        drift: 0.02 + random.nextDouble() * 0.05,
        phase: random.nextDouble() * math.pi * 2,
        spin: (random.nextDouble() - 0.5) * 3,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final SettingsController? settings = SettingsScope.maybeOf(context);

    final String? imagePath = settings?.snowImagePath;
    final int count = (settings?.snowCount ?? 26).clamp(5, 100);
    final double size = (settings?.snowSize ?? 10).clamp(4.0, 60.0);
    final double speed = (settings?.snowSpeed ?? 1.0).clamp(0.2, 3.0);

    _maybeLoadImage(imagePath);
    if (count != _count) {
      _count = count;
      _snow = _build(count);
    }

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return CustomPaint(
              size: Size.infinite,
              painter: _SnowPainter(
                t: _controller.value * speed,
                snow: _snow,
                image: _image,
                sizeScale: size / 10,
                color: colors.accent,
                dim: colors.ink,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Snow {
  const _Snow({
    required this.x,
    required this.offset,
    required this.speed,
    required this.size,
    required this.drift,
    required this.phase,
    required this.spin,
  });

  final double x;
  final double offset;
  final double speed;
  final double size;
  final double drift;
  final double phase;
  final double spin;
}

class _SnowPainter extends CustomPainter {
  _SnowPainter({
    required this.t,
    required this.snow,
    required this.image,
    required this.sizeScale,
    required this.color,
    required this.dim,
  });

  final double t;
  final List<_Snow> snow;
  final ui.Image? image;
  final double sizeScale;
  final Color color;
  final Color dim;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..filterQuality = FilterQuality.low;

    for (final _Snow p in snow) {
      final double progress = (p.offset + t * p.speed) % 1.0;
      final double y = progress * (size.height + 60) - 30;
      final double x = p.x * size.width +
          math.sin(t * math.pi * 2 + p.phase) * p.drift * size.width;
      final double fade = math.sin(progress * math.pi).clamp(0.0, 1.0);
      final double r = p.size * sizeScale;

      if (image != null) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(p.phase + t * p.spin);
        final Rect dst =
            Rect.fromCenter(center: Offset.zero, width: r * 3, height: r * 3);
        final Rect src = Rect.fromLTWH(
          0,
          0,
          image!.width.toDouble(),
          image!.height.toDouble(),
        );
        paint.color = Colors.white.withOpacity(0.15 + 0.45 * fade);
        canvas.drawImageRect(image!, src, dst, paint);
        canvas.restore();
      } else {
        paint.color =
            Color.lerp(dim, color, 0.45)!.withOpacity(0.10 + 0.16 * fade);
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.image != image ||
        oldDelegate.sizeScale != sizeScale ||
        oldDelegate.color != color ||
        oldDelegate.dim != dim ||
        oldDelegate.snow.length != snow.length;
  }
}
