import 'package:flutter/material.dart';

/// 果冻弹入的页面转场：缩放用 elasticOut（带轻微回弹），配合淡入。
///
/// 用法：`Navigator.of(context).push(JellyPageRoute(builder: (_) => SomePage()));`
class JellyPageRoute<T> extends PageRouteBuilder<T> {
  JellyPageRoute({
    required this.builder,
    super.settings,
    this.axisAlign = Alignment.center,
  }) : super(
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 560),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondary) {
            return builder(context);
          },
          transitionsBuilder: (BuildContext context,
              Animation<double> animation,
              Animation<double> secondary,
              Widget child) {
            final Animation<double> jelly = CurvedAnimation(
              parent: animation,
              curve: Curves.elasticOut,
              reverseCurve: Curves.easeInCubic,
            );
            final Animation<double> fade = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
            );
            final Animation<double> wobble = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            );

            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.78, end: 1.0).animate(jelly),
                alignment: axisAlign,
                child: RotationTransition(
                  turns: Tween<double>(begin: 0.012, end: 0).animate(wobble),
                  child: child,
                ),
              ),
            );
          },
        );

  final WidgetBuilder builder;

  /// 缩放的锚点，默认从中间弹入。
  final Alignment axisAlign;
}
