import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data' show ByteData;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/settings_controller.dart';
import '../design/tokens.dart';

class SnowOverlay extends StatefulWidget {
  const SnowOverlay({super.key});

  @override
  State<SnowOverlay> createState() => _SnowOverlayState();
}

class _SnowOverlayState extends State<SnowOverlay> {
  final ValueNotifier<double> _phase = ValueNotifier<double>(0);
  Timer? _timer;
  Stopwatch? _stopwatch;

  ui.Image? _image;
  String? _imageKey;
  int _count = -1;
  List<_Snow> _snow = <_Snow>[];

  static const String _assetSnow = 'assets/images/snowflake.png';

  @override
  void initState() {
    super.initState();
    final bool reduce = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (!reduce) {
      _stopwatch = Stopwatch()..start();
      _timer = Timer.periodic(const Duration(milliseconds: 16), (Timer timer) {
        if (!mounted) return;
        _phase.value = (_stopwatch!.elapsedMicroseconds / 22000000.0) % 1.0;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phase.dispose();
    super.dispose();
  }

  void _maybeLoadImage(String? path) {
    final String key = (path == null || path.isEmpty) ? '@asset' : 'file:$path';
    if (key == _imageKey) return;
    _imageKey = key;
    _image = null;

    void apply(ui.Image img) {
      if (mounted && _imageKey == key) {
        setState(() => _image = img);
      }
    }

    if (key == '@asset') {
      rootBundle.load(_assetSnow).then((ByteData data) {
        ui.decodeImageFromList(data.buffer.asUint8List(), apply);
      }).catchError((Object _) {});
      return;
    }

    final File file = File(path!);
    if (!file.existsSync()) return;
    file.readAsBytes().then((bytes) {
      ui.decodeImageFromList(bytes, apply);
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
          animation: _phase,
          builder: (BuildContext context, Widget? child) {
            return CustomPaint(
              size: Size.infinite,
              painter: _SnowPainter(
                t: _phase.value * speed,
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
