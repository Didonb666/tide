import 'package:flutter/services.dart';

import 'tunnel_platform.dart';
import 'tunnel_state.dart';
import '../app_text.dart';

/// Android 原生实现。
///
/// 通道约定（与 `android/.../TunnelChannel.kt` 一一对应）：
///   MethodChannel `tide/tunnel`
///     - isAvailable() -> bool
///     - getState()    -> Map
///     - connect({profileId}) -> void
///     - disconnect()  -> void
///   EventChannel  `tide/tunnel/events` -> Map（字段见 TunnelState.fromMap）
///
/// 注意：**没有**在 Windows 上注册处理器，调用会抛 MissingPluginException。
/// 这里全部捕获并降级，保证同一套 Dart 代码在桌面端不会崩。
class MethodChannelTunnelPlatform implements TunnelPlatform {
  /// 最近一次通道调用失败的原因（用于界面提示）
  static String? lastError;

  static const MethodChannel _methods = MethodChannel('tide/tunnel');
  static EventChannel _events = EventChannel('tide/tunnel/events');

  Stream<TunnelState>? _states;

  @override
  Future<bool> isAvailable() async {
    try {
      final bool? value = await _methods.invokeMethod<bool>('isAvailable');
      return value ?? false;
    } on MissingPluginException catch (error) {
      lastError = 'MissingPluginException: ${error.message}';
      return false;
    } on PlatformException catch (error) {
      lastError = 'PlatformException: ${error.code} ${error.message}';
      return false;
    } catch (error) {
      lastError = '$error';
      return false;
    }
  }

  @override
  Future<TunnelState> readState() async {
    try {
      final Map<Object?, Object?>? map =
          await _methods.invokeMapMethod<Object?, Object?>('getState');
      if (map == null) return TunnelState();
      return TunnelState.fromMap(map);
    } on MissingPluginException {
      return TunnelState();
    } on PlatformException {
      return TunnelState();
    }
  }

  @override
  Future<void> connect(
    String profileId,
    String configYaml, {
    required String secret,
    required int port,
    bool ipv6 = true,
  }) async {
    try {
      await _methods.invokeMethod<void>(
        'connect',
        <String, Object?>{
          'profileId': profileId,
          'config': configYaml,
          'secret': secret,
          'port': port,
          'ipv6': ipv6,
        },
      );
    } on MissingPluginException {
      // 桌面端没有原生实现：交给上层降级处理。
      throw StateError(tr('当前平台没有原生隧道实现'));
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _methods.invokeMethod<void>('disconnect');
    } on MissingPluginException {
      throw StateError(tr('当前平台没有原生隧道实现'));
    }
  }

  @override
  Stream<TunnelState> get states {
    final Stream<TunnelState>? cached = _states;
    if (cached != null) return cached;

    final Stream<TunnelState> created =
        _events.receiveBroadcastStream().map<TunnelState>(
      (dynamic event) => TunnelState.fromMap(
        (event as Map).cast<Object?, Object?>(),
      ),
    );
    _states = created;
    return created;
  }

  @override
  Future<void> dispose() async {}
}
