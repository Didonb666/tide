import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/background_controller.dart';

/// 全局背景层：按屏幕方向选择背景（竖屏优先竖屏槽位，横屏优先横屏槽位，
/// 都没设置时回落到统一背景，最后回落到内置默认图）。
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

  void _syncVideo(String? target) {
    if (target == _videoPath) return;

    _videoPath = target;
    _video?.dispose();
    _video = null;

    if (target == null || !mounted) return;

    final VideoPlayerController video = VideoPlayerController.file(File(target));
    video.setLooping(true);
    video.setVolume(0);
    _video = video;

    video.initialize().then((_) {
      if (!mounted || _videoPath != target) return;
      setState(() {});
      video.play();
    }).catchError((Object _) {
      if (!mounted || _videoPath != target) return;
      _videoPath = null;
      _video = null;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final BackgroundController bg = BackgroundScope.of(context);
    final Orientation orientation = MediaQuery.orientationOf(context);

    return AnimatedBuilder(
      animation: bg,
      builder: (BuildContext context, Widget? child) {
        final String? path = bg.pathFor(orientation);
        final bool isVideo = bg.isVideoFor(orientation);

        _syncVideo(isVideo ? path : null);

        // 没有任何自定义背景：用内置默认图（原样显示，不加透明度/模糊）。
        if (path == null) {
          return Positioned.fill(
            child: Image.asset(
              'assets/images/default_background.webp',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
              ) {
                return const ColoredBox(color: Color(0xFF070A10));
              },
            ),
          );
        }

        final Widget media;
        if (isVideo) {
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
            media = const ColoredBox(color: Color(0xFF070A10));
          }
        } else {
          media = Image.file(
            File(path),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
            ) {
              return const ColoredBox(color: Color(0xFF070A10));
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
