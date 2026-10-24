package com.fstool.app

import android.content.Intent
import android.os.Build
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var tunnelChannel: TunnelChannel? = null
    private var displayChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        tunnelChannel = TunnelChannel(
            this,
            flutterEngine.dartExecutor.binaryMessenger
        ).also { it.attach() }

        displayChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fstool/display"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setRefreshRate" -> {
                        val hz = call.argument<Double>("hz") ?: 60.0
                        applyRefreshRate(hz)
                        result.success(true)
                    }
                    "currentRefreshRate" -> result.success(currentRefreshRate())
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun currentRefreshRate(): Double {
        val w = window ?: return 60.0
        return w.decorView.display?.refreshRate?.toDouble() ?: 60.0
    }

    private fun applyRefreshRate(hz: Double) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val w = window ?: return
        val display: Display = w.decorView.display ?: return

        var best: Display.Mode? = null
        var bestDelta = Double.MAX_VALUE
        for (mode in display.supportedModes) {
            val delta = kotlin.math.abs(mode.refreshRate - hz)
            if (delta < bestDelta) {
                bestDelta = delta
                best = mode
            }
        }

        val target = best ?: return
        val attrs = w.attributes
        attrs.preferredDisplayModeId = target.modeId
        w.attributes = attrs
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        tunnelChannel?.onActivityResult(requestCode, resultCode)
    }
}
