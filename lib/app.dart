import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'core/app_controller.dart';
import 'core/app_scope.dart';
import 'core/background_controller.dart';
import 'core/settings_controller.dart';
import 'design/app_theme.dart';
import 'design/tokens.dart';
import 'features/connect/connect_page.dart';
import 'features/logs/logs_page.dart';
import 'features/profiles/profiles_page.dart';
import 'features/settings/settings_page.dart';
import 'widgets/aurora_background.dart';
import 'widgets/liquid_nav_bar.dart';
import 'widgets/snow_overlay.dart';
import 'widgets/folia_button.dart';
import 'features/experimental/glass_lab_page.dart';

class TideApp extends StatelessWidget {
  const TideApp({
    super.key,
    required this.controller,
    required this.settings,
    required this.background,
  });

  final AppController controller;
  final SettingsController settings;
  final BackgroundController background;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: SettingsScope(
        controller: settings,
        child: BackgroundScope(
          controller: background,
          child: AnimatedBuilder(
            animation: settings,
            builder: (BuildContext context, Widget? child) {
              return MaterialApp(
                title: 'Fstool',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(settings.accentColor),
                darkTheme: AppTheme.dark(settings.accentColor),
                themeMode: settings.themeMode,
                            scrollBehavior: const TideScrollBehavior(),
                builder: (BuildContext context, Widget? child) {
                  return Stack(
                    children: <Widget>[
                      const AppBackgroundHost(),
                      if (child != null) child,
                      const SnowOverlay(),
                    ],
                  );
                },
                home: const HomeShell(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<Widget> _pages = <Widget>[
    ConnectPage(),
    ProfilesPage(),
    LogsPage(),
    SettingsPage(),
  ];

  static const List<LiquidNavItem> _navItems = <LiquidNavItem>[
    LiquidNavItem(
      icon: Icons.power_settings_new_outlined,
      activeIcon: Icons.power_settings_new_rounded,
      label: '连接',
    ),
    LiquidNavItem(
      icon: Icons.layers_outlined,
      activeIcon: Icons.layers_rounded,
      label: '配置',
    ),
    LiquidNavItem(
      icon: Icons.article_outlined,
      activeIcon: Icons.article_rounded,
      label: '日志',
    ),
    LiquidNavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: '设置',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final Duration duration = context.motion(TideMotion.base);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          IndexedStack(index: _index, children: _pages),
          if (_index == 0)
            const Positioned(
              right: 20,
              bottom: 112,
              child: FoliaButton(),
            ),
        ],
      ),
      bottomNavigationBar: LiquidNavBar(
        index: _index,
        onTap: (int value) => setState(() => _index = value),
        items: _navItems,
      ),
    );
  }
}

class _ParticleOverlay extends StatefulWidget {
  const _ParticleOverlay({this.count = 26});

  final int count;

  @override
  State<_ParticleOverlay> createState() => _ParticleOverlayState();
}

class _ParticleOverlayState extends State<_ParticleOverlay>
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
      final double x = p.x * size.width +
          math.sin(t * math.pi * 2 + p.phase) * p.drift * size.width;
      final double fade = math.sin(progress * math.pi).clamp(0.0, 1.0);

      paint.color =
          Color.lerp(dim, color, 0.45)!.withOpacity(0.10 + 0.16 * fade);
      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.color != color;
  }
}



/// 关掉 Android 12+ 的拉伸回弹：它会在列表拉到尽头时整体缩放内容，
/// 导致 BackdropFilter 采样错位，玻璃看起来"掉模糊"。
class TideScrollBehavior extends MaterialScrollBehavior {
  const TideScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
