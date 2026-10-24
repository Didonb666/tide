import 'package:flutter/foundation.dart';

/// 隧道生命周期。与原生侧（Android Kotlin）的状态字符串一一对应。
enum TunnelPhase { idle, connecting, connected, disconnecting, failed }

@immutable
class TunnelState {
  const TunnelState({
    this.phase = TunnelPhase.idle,
    this.profileId,
    this.message,
    this.downBytesPerSec = 0,
    this.upBytesPerSec = 0,
    this.connectionCount = 0,
    this.nativeAvailable = false,
  });

  final TunnelPhase phase;

  /// 当前连接的配置 id。
  final String? profileId;

  /// 给用户看的一句话状态说明（来自原生层）。
  final String? message;

  final int downBytesPerSec;
  final int upBytesPerSec;
  final int connectionCount;

  /// 是否运行在"真实原生隧道"上。false 表示这是演示/壳子模式。
  final bool nativeAvailable;

  bool get isConnected => phase == TunnelPhase.connected;
  bool get isBusy =>
      phase == TunnelPhase.connecting || phase == TunnelPhase.disconnecting;

  String get label {
    switch (phase) {
      case TunnelPhase.idle:
        return '未连接';
      case TunnelPhase.connecting:
        return '连接中';
      case TunnelPhase.connected:
        return '已连接';
      case TunnelPhase.disconnecting:
        return '正在断开';
      case TunnelPhase.failed:
        return '连接失败';
    }
  }

  TunnelState copyWith({
    TunnelPhase? phase,
    String? profileId,
    String? message,
    int? downBytesPerSec,
    int? upBytesPerSec,
    int? connectionCount,
    bool? nativeAvailable,
  }) {
    return TunnelState(
      phase: phase ?? this.phase,
      profileId: profileId ?? this.profileId,
      message: message ?? this.message,
      downBytesPerSec: downBytesPerSec ?? this.downBytesPerSec,
      upBytesPerSec: upBytesPerSec ?? this.upBytesPerSec,
      connectionCount: connectionCount ?? this.connectionCount,
      nativeAvailable: nativeAvailable ?? this.nativeAvailable,
    );
  }

  /// 解析原生侧通过 MethodChannel / EventChannel 返回的 Map。
  /// 键名同时兼容 Kotlin 与未来 Windows 实现的命名。
  static TunnelState fromMap(Map<Object?, Object?> map) {
    return TunnelState(
      phase: _parsePhase(map['phase']),
      profileId: map['profileId'] is String ? map['profileId'] as String : null,
      message: map['message'] is String ? map['message'] as String : null,
      downBytesPerSec: _asInt(map['down']),
      upBytesPerSec: _asInt(map['up']),
      connectionCount: _asInt(map['connectionCount']),
      nativeAvailable: map['nativeAvailable'] == true,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static TunnelPhase _parsePhase(Object? value) {
    switch (value) {
      case 'connecting':
        return TunnelPhase.connecting;
      case 'connected':
        return TunnelPhase.connected;
      case 'disconnecting':
        return TunnelPhase.disconnecting;
      case 'failed':
        return TunnelPhase.failed;
      default:
        return TunnelPhase.idle;
    }
  }
}
