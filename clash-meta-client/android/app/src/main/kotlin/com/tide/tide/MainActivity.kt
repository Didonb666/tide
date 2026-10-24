package com.tide.tide

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * 原生入口。
 *
 * 只做一件事：把 TunnelChannel 注册到 Flutter 引擎上。
 * 真正的 VpnService / 内核启动逻辑在第二阶段才进来（docs/PHASE2_CORE.md），
 * 这样第一阶段的两个 Job 都不需要 NDK、Go、gomobile 就能编译通过。
 */
class MainActivity : FlutterActivity() {

    private var tunnelChannel: TunnelChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 持有引用，避免通道对象被回收（setMethodCallHandler 只保存弱引用）。
        tunnelChannel = TunnelChannel(flutterEngine.dartExecutor.binaryMessenger).also {
            it.attach()
        }
    }
}
