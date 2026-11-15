import 'package:flutter/foundation.dart';

import 'method_channel_tunnel.dart';
import 'simulated_tunnel.dart';
import 'windows_mihomo_tunnel.dart';
import 'tunnel_platform.dart';

/// 平台选择只发生在这里。
///
/// - Android：走 MethodChannel，失败时 Controller 会自动回退到模拟实现；
/// - Windows / macOS / Linux / Web：直接模拟实现（暂不接原生）。
///
/// 以后要接 Windows 原生隧道，只需在这里加一个 `TargetPlatform.windows` 分支。
TunnelPlatform createTunnelPlatform() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return MethodChannelTunnelPlatform();
  }
  // Windows：随包分发 mihomo.exe，可用则走真实内核（不可用时上层自动回退到模拟）
  if (defaultTargetPlatform == TargetPlatform.windows) {
    return WindowsMihomoTunnelPlatform();
  }
  return SimulatedTunnelPlatform();
}
