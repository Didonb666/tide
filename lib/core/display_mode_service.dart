import 'dart:ui' show FramePhase;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// 通过原生 Window 切换显示刷新率；桌面端没有实现时静默忽略。
class DisplayModeService {
  static const MethodChannel _channel = MethodChannel('fstool/display');

  static Future<void> applyRefreshRate(int hz) async {
    try {
      await _channel.invokeMethod<bool>(
        'setRefreshRate',
        <String, Object?>{'hz': hz.toDouble()},
      );
    } catch (_) {}
  }

  static Future<double?> currentRefreshRate() async {
    try {
      return await _channel.invokeMethod<double>('currentRefreshRate');
    } catch (_) {
      return null;
    }
  }
}

/// 用 SchedulerBinding 的帧回调实测当前 FPS，供设置页展示。
class FpsMonitor {
  FpsMonitor._();

  static final FpsMonitor instance = FpsMonitor._();

  final ValueNotifier<double> fps = ValueNotifier<double>(0);

  int _frames = 0;
  int? _windowStartMs;
  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    _frames = 0;
    _windowStartMs = null;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_running) return;
    _running = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final FrameTiming timing in timings) {
      final int nowMs =
          timing.timestampInMicroseconds(FramePhase.rasterFinish) ~/ 1000;
      _windowStartMs ??= nowMs;
      _frames += 1;
      final int elapsed = nowMs - _windowStartMs!;
      if (elapsed >= 1000) {
        fps.value = _frames * 1000 / elapsed;
        _frames = 0;
        _windowStartMs = nowMs;
      }
    }
  }
}
