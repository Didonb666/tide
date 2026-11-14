import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_controller.dart';
import 'core/app_scope.dart';
import 'core/app_text.dart';
import 'core/background_controller.dart';
import 'core/license/license_controller.dart';
import 'core/license/license_scope.dart';
import 'core/locale_controller.dart';
import 'core/settings_controller.dart';
import 'design/app_theme.dart';
import 'design/tokens.dart';
import 'features/auth/license_gate.dart';
import 'features/auth/redeem_page.dart';
import 'features/connect/connect_page.dart';
import 'features/logs/logs_page.dart';
import 'features/profile/profile_page.dart';
import 'features/profiles/profiles_page.dart';
import 'widgets/aurora_background.dart';
import 'widgets/liquid_nav_bar.dart';
import 'widgets/snow_overlay.dart';
import 'core/jelly_route.dart';

class TideApp extends StatelessWidget {
  const TideApp({
    super.key,
    required this.controller,
    required this.settings,
    required this.background,
    required this.license,
    required this.locale,
  });

  final AppController controller;
  final SettingsController settings;
  final BackgroundController background;
  final LicenseController license;
  final LocaleController locale;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: SettingsScope(
        controller: settings,
        child: BackgroundScope(
          controller: background,
          child: LocaleScope(
            controller: locale,
            // LicenseScope 放在 MaterialApp 外层：
            // 这样 push 出来的新路由（兑换页等）也能读到授权状态，
            // 否则会 assert 失败 → 白屏。
            child: LicenseScope(
              controller: license,
              child: AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[settings, locale]),
                builder: (BuildContext context, Widget? child) {
                  return MaterialApp(
                    title: 'Fstool',
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.light(settings.accentColor),
                    darkTheme: AppTheme.dark(settings.accentColor),
                    themeMode: settings.themeMode,
                    locale: locale.locale,
                    supportedLocales: const <Locale>[
                      Locale('zh'),
                      Locale('en'),
                      Locale('it'),
                      Locale('ru'),
                    ],
                    localizationsDelegates:
                        const <LocalizationsDelegate<dynamic>>[
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
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
                    home: const LicenseGate(child: HomeShell()),
                  );
                },
              ),
            ),
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
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final Duration duration = context.motion(TideMotion.base);

    final List<LiquidNavItem> navItems = <LiquidNavItem>[
      LiquidNavItem(
        icon: Icons.power_settings_new_outlined,
        activeIcon: Icons.power_settings_new_rounded,
        label: AppText.t(context, 'nav.connect'),
      ),
      LiquidNavItem(
        icon: Icons.layers_outlined,
        activeIcon: Icons.layers_rounded,
        label: AppText.t(context, 'nav.profiles'),
      ),
      LiquidNavItem(
        icon: Icons.article_outlined,
        activeIcon: Icons.article_rounded,
        label: AppText.t(context, 'nav.logs'),
      ),
      LiquidNavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: AppText.t(context, 'nav.mine'),
      ),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Column(
        children: <Widget>[
          const _NoTimeBanner(),
          Expanded(
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: TideMotion.standard,
              switchOutCurve: TideMotion.standard,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.02, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: IndexedStack(
                index: _index,
                children: _pages,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: LiquidNavBar(
        index: _index,
        onTap: (int value) => setState(() => _index = value),
        items: navItems,
      ),
    );
  }
}

/// 没有可用时长时顶部的提示条，点一下直接去兑换。
class _NoTimeBanner extends StatelessWidget {
  const _NoTimeBanner();

  @override
  Widget build(BuildContext context) {
    final LicenseController? license = LicenseScope.maybeOf(context);
    if (license == null || license.hasTime) return const SizedBox.shrink();

    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Material(
          color: colors.accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(TideRadii.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(TideRadii.md),
            onTap: () => showRedeemDialog(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: <Widget>[
                  Icon(Icons.timer_outlined, size: 16, color: colors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppText.t(context, 'banner.noTime'),
                      style: text.labelMedium?.copyWith(color: colors.accent),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colors.accent,
                  ),
                ],
              ),
            ),
          ),
        ),
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
          Color.lerp(dim, color, 0.45)!.withValues(alpha: 0.10 + 0.16 * fade);
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
