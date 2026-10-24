package com.tide.tide

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * 原生入口：注册通道，并把 VPN 授权结果转发给通道。
 */
class MainActivity : FlutterActivity() {

    private var tunnelChannel: TunnelChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 持有引用，避免通道对象被回收。
        tunnelChannel = TunnelChannel(
            this,
            flutterEngine.dartExecutor.binaryMessenger
        ).also { it.attach() }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        tunnelChannel?.onActivityResult(requestCode, resultCode)
    }
}
