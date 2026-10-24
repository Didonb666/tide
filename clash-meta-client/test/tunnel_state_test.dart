import 'package:flutter_test/flutter_test.dart';

import 'package:tide/core/tunnel/tunnel_state.dart';

void main() {
  test('TunnelState.fromMap 能解析原生侧返回的阶段', () {
    final state = TunnelState.fromMap(<Object?, Object?>{
      'phase': 'connected',
      'profileId': 'p-main',
      'nativeAvailable': true,
    });

    expect(state.isConnected, isTrue);
    expect(state.profileId, 'p-main');
    expect(state.nativeAvailable, isTrue);
  });

  test('未知阶段退化为 idle', () {
    final state = TunnelState.fromMap(<Object?, Object?>{'phase': 'wat'});
    expect(state.phase, TunnelPhase.idle);
  });
}
