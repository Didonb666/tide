package com.tide.tide

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * 第一阶段的原生通道：**不建立 VPN、不接管流量**，只把状态机跑起来。
 *
 * 目的有两个：
 *   1. 证明 Flutter <-> Kotlin 的 MethodChannel / EventChannel 在真机上确实通了；
 *   2. 让 Dart 侧的 TunnelPlatform 有一个真实的原生实现可以切换，
 *      第二阶段把内部改成 VpnService + mihomo 时，Dart 代码一行都不用改。
 *
 * 通道协议（与 lib/core/tunnel/method_channel_tunnel.dart 严格对应）：
 *   MethodChannel "tide/tunnel"
 *     isAvailable()            -> Boolean
 *     getState()               -> Map
 *     connect({profileId})     -> Map
 *     disconnect()             -> Map
 *   EventChannel "tide/tunnel/events" -> Map
 *
 * Map 字段：phase / profileId / message / nativeAvailable / down / up / connectionCount
 */
class TunnelChannel(messenger: BinaryMessenger) {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val methodChannel = MethodChannel(messenger, "tide/tunnel")
    private val eventChannel = EventChannel(messenger, "tide/tunnel/events")

    private var sink: EventChannel.EventSink? = null
    private var phase: String = "idle"
    private var profileId: String? = null
    private var pending: Runnable? = null

    fun attach() {
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sink = events
                emit()
            }

            override fun onCancel(arguments: Any?) {
                sink = null
            }
        })

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(true)
                "getState" -> result.success(snapshot())
                "connect" -> {
                    connect(call.argument<String>("profileId"))
                    result.success(snapshot())
                }
                "disconnect" -> {
                    disconnect()
                    result.success(snapshot())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun snapshot(): Map<String, Any?> {
        val connected = phase == "connected"
        return mapOf<String, Any?>(
            "phase" to phase,
            "profileId" to profileId,
            "nativeAvailable" to false,
            "message" to messageForPhase(),
            "down" to if (connected) 262144 else 0,
            "up" to if (connected) 32768 else 0,
            "connectionCount" to if (connected) 7 else 0
        )
    }

    private fun messageForPhase(): String = when (phase) {
        "connecting" -> "正在建立隧道…（Android 原生通道演示）"
        "connected" -> "已连接（Android 原生通道演示，未接入内核）"
        "disconnecting" -> "正在断开…"
        else -> "未连接"
    }

    private fun emit() {
        sink?.success(snapshot())
    }

    private fun connect(id: String?) {
        cancelPending()
        profileId = id
        phase = "connecting"
        emit()

        val task = Runnable {
            phase = "connected"
            pending = null
            emit()
        }
        pending = task
        mainHandler.postDelayed(task, 900L)
    }

    private fun disconnect() {
        cancelPending()
        phase = "disconnecting"
        emit()

        val task = Runnable {
            phase = "idle"
            profileId = null
            pending = null
            emit()
        }
        pending = task
        mainHandler.postDelayed(task, 400L)
    }

    private fun cancelPending() {
        pending?.let { mainHandler.removeCallbacks(it) }
        pending = null
    }
}
