import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// 顶层粒子飘落：IgnorePointer 不挡点击，RepaintBoundary 限制重绘。
class ParticleOverlay extends StatefulWidget {
  const ParticleOverlay({super.key, this.count = 26});

  final int count;

  @override
  State<ParticleOverlay> createState() => _ParticleOverlayState();
}

class _ParticleOverlayState extends State<ParticleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  );

  late final List<_Particle> _particles = _buildParticles();

  List<_Particle> _buildParticles() {
    final math.Random random = math.Random(20261024);
    return List<_Particle>.generate(widget.count, (int index) {
      return _Particle(
        x: random.nextDouble(),
        offset: random.nextDouble(),
        speed: 0.35 + random.nextDouble() * 0.55,
        size: 1.2 + random.nextDouble() * 2.2,
        drift: 0.02 + random.nextDouble() * 0.05,
        phase: random.nextDouble() * math.pi * 2,
      );
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return CustomPaint(
              size: Size.infinite,
              painter: _ParticlePainter(
                t: _controller.value,
                particles: _particles,
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

class _Particle {
  const _Particle({
    required this.x,
    required this.offset,
    required this.speed,
    required this.size,
    required this.drift,
    required this.phase,
  });

  final double x;
  final double offset;
  final double speed;
  final double size;
  final double drift;
  final double phase;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.t,
    required this.particles,
    required this.color,
    required this.dim,
  });

  final double t;
  final List<_Particle> particles;
  final Color color;
  final Color dim;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (final _Particle p in particles) {
      final double progress = (p.offset + t * p.speed) % 1.0;
      final double y = progress * (size.height + 40) - 20;
      final double x =
          p.x * size.width + math.sin(t * math.pi * 2 + p.phase) * p.drift * size.width;
      final double fade = math.sin(progress * math.pi).clamp(0.0, 1.0);

      paint.color = Color.lerp(dim, color, 0.45)!.withOpacity(0.10 + 0.16 * fade);
      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.color != color;
  }
}
