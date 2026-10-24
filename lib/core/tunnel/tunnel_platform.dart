import 'tunnel_state.dart';

/// 双端唯一的隧道抽象。
///
/// 上层（UI / Controller）只认这个接口；Android 走 MethodChannel，
/// Windows / 其他平台走本地模拟实现。新增平台时只需再加一个实现，
/// 不会碰到任何页面代码。
abstract class TunnelPlatform {
  /// 原生实现是否可用。false 时调用方应回退到 [SimulatedTunnelPlatform]。
  Future<bool> isAvailable();

  /// 主动拉一次当前状态（用于首帧，避免等事件）。
  Future<TunnelState> readState();

  /// 启动隧道。
  ///
  /// - [configYaml]：用户导入的原始 Clash.Meta 配置，原样交给内核解析；
  /// - [secret]：本次会话随机生成的 32 字节密钥，用于保护本机 REST API；
  /// - [port]：本机 REST API 端口，每次连接随机。
  Future<void> connect(
    String profileId,
    String configYaml, {
    required String secret,
    required int port,
    bool ipv6 = true,
  });

  Future<void> disconnect();

  /// 状态推送。原生层通过 EventChannel 发送。
  Stream<TunnelState> get states;

  Future<void> dispose();
}
