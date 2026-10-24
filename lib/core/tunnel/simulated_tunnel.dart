import 'dart:async';
import 'dart:math';

import 'tunnel_platform.dart';
import 'tunnel_state.dart';

/// 桌面端（以及任何没有原生实现的平台）使用的本地模拟实现。
///
/// 它不建立任何隧道、不接管流量，只负责把状态机跑起来，
/// 让 UI、动效、按钮逻辑在不接内核的情况下也能完整走通。
class SimulatedTunnelPlatform implements TunnelPlatform {
  final StreamController<TunnelState> _controller =
      StreamController<TunnelState>.broadcast();
  final Random _random = Random(7);

  TunnelState _state = const TunnelState(message: '演示模式：未接入内核');
  Timer? _traffic;
  bool _disposed = false;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<TunnelState> readState() async => _state;

  @override
  Stream<TunnelState> get states => _controller.stream;

  void _emit(TunnelState next) {
    if (_disposed) return;
    _state = next;
    _controller.add(next);
  }

  @override
  Future<void> connect(
    String profileId,
    String configYaml, {
    required String secret,
    required int port,
    bool ipv6 = true,
  }) async {
    if (_state.isConnected || _state.isBusy) return;

    _emit(_state.copyWith(
      phase: TunnelPhase.connecting,
      profileId: profileId,
      message: '正在建立隧道…',
    ));

    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (_disposed) return;

    _emit(_state.copyWith(
      phase: TunnelPhase.connected,
      message: '已连接（桌面演示模式，未启动内核）',
    ));
    _startTraffic();
  }

  @override
  Future<void> disconnect() async {
    _stopTraffic();
    _emit(_state.copyWith(
      phase: TunnelPhase.disconnecting,
      message: '正在断开…',
    ));

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (_disposed) return;

    _emit(_state.copyWith(
      phase: TunnelPhase.idle,
      downBytesPerSec: 0,
      upBytesPerSec: 0,
      connectionCount: 0,
      message: '已断开',
    ));
  }

  void _startTraffic() {
    _traffic?.cancel();
    _traffic = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      final int down = 18000 + _random.nextInt(820000);
      final int up = 2400 + _random.nextInt(72000);
      _emit(_state.copyWith(
        downBytesPerSec: down,
        upBytesPerSec: up,
        connectionCount: 3 + _random.nextInt(16),
      ));
    });
  }

  void _stopTraffic() {
    _traffic?.cancel();
    _traffic = null;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _stopTraffic();
    await _controller.close();
  }
}
