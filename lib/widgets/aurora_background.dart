import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/background_controller.dart';
import '../design/tokens.dart';

/// 极光流动背景：三个缓慢漂移的径向渐变光斑。
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final bool dark = context.isDark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _AuroraPainter(
            t: _controller.value,
            colors: <Color>[
              colors.accent,
              colors.info,
              const Color(0xFF7C5CFF),
            ],
            base: dark ? const Color(0xFF070A10) : const Color(0xFFEAF2FB),
            dark: dark,
          ),
        );
      },
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.t,
    required this.colors,
    required this.base,
    required this.dark,
  });

  final double t;
  final List<Color> colors;
  final Color base;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = base);

    for (int i = 0; i < colors.length; i++) {
      final double phase = t * 2 * math.pi + i * 2.09;
      final Offset center = Offset(
        size.width * (0.5 + 0.38 * math.sin(phase)),
        size.height * (0.5 + 0.38 * math.cos(phase * 1.13 + i)),
      );
      final Paint paint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            colors[i].withOpacity(dark ? 0.36 : 0.30),
            colors[i].withOpacity(0.0),
          ],
          stops: const <double>[0.0, 1.0],
        ).createShader(
          Rect.fromCircle(
            center: center,
            radius: size.shortestSide * 0.62,
          ),
        );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.base != base ||
        oldDelegate.dark != dark;
  }
}

/// 全局背景层：优先自定义媒体（图片/视频），否则极光。
/// 挂在 MaterialApp.builder 的 Stack 最底层。
class AppBackgroundHost extends StatefulWidget {
  const AppBackgroundHost({super.key});

  @override
  State<AppBackgroundHost> createState() => _AppBackgroundHostState();
}

class _AppBackgroundHostState extends State<AppBackgroundHost>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _video?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final VideoPlayerController? video = _video;
    if (video == null) return;
    if (state == AppLifecycleState.resumed) {
      video.play();
    } else {
      video.pause();
    }
  }

  void _syncVideo(BackgroundController bg) {
    final String? target =
        (bg.isVideo && bg.mediaPath != null) ? bg.mediaPath : null;
    if (target == _videoPath) return;

    _videoPath = target;
    _video?.dispose();
    _video = null;

    if (target == null || !mounted) return;

    final VideoPlayerController video =
        VideoPlayerController.file(File(target));
    video.setLooping(true);
    video.setVolume(0);
    _video = video;

    video.initialize().then((_) {
      if (!mounted || _videoPath != target) return;
      setState(() {});
      video.play();
    }).catchError((Object _) {
      // 平台不支持视频时回退极光，不崩溃。
      if (!mounted || _videoPath != target) return;
      _videoPath = null;
      _video = null;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final BackgroundController bg = BackgroundScope.of(context);
    _syncVideo(bg);

    return AnimatedBuilder(
      animation: bg,
      builder: (BuildContext context, Widget? child) {
        final Widget media;

        if (bg.mediaPath == null) {
          media = const AuroraBackground();
        } else if (bg.isVideo) {
          final VideoPlayerController? video = _video;
          if (video != null && video.value.isInitialized) {
            media = SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: video.value.size.width,
                  height: video.value.size.height,
                  child: VideoPlayer(video),
                ),
              ),
            );
          } else {
            media = const AuroraBackground();
          }
        } else {
          media = Image.file(
            File(bg.mediaPath!),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
              return const AuroraBackground();
            },
          );
        }

        return Positioned.fill(
          child: Opacity(
            opacity: bg.opacity,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: bg.blur, sigmaY: bg.blur),
              child: media,
            ),
          ),
        );
      },
    );
  }
}
