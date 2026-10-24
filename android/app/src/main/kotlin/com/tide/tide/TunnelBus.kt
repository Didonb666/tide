package com.fstool.app

import java.util.concurrent.CopyOnWriteArrayList

/**
 * 隧道状态的单点广播。
 *
 * 为什么不直接让 Service 持有 EventChannel：
 *   Service 可能被系统重建、TunnelChannel 又绑在 Activity 上，
 *   两边生命周期不一致。用一个进程级单例做缓冲，谁先来谁后到都不会丢状态。
 */
object TunnelBus {

    private val listeners = CopyOnWriteArrayList<(Map<String, Any?>) -> Unit>()

    @Volatile
    var last: Map<String, Any?> = idle()
        private set

    fun publish(state: Map<String, Any?>) {
        last = state
        listeners.forEach { listener ->
            runCatching { listener(state) }
        }
    }

    fun addListener(listener: (Map<String, Any?>) -> Unit) {
        listeners.addIfAbsent(listener)
    }

    fun removeListener(listener: (Map<String, Any?>) -> Unit) {
        listeners.remove(listener)
    }

    fun state(
        phase: String,
        profileId: String?,
        message: String,
        nativeAvailable: Boolean,
        coreVersion: String?
    ): Map<String, Any?> = mapOf(
        "phase" to phase,
        "profileId" to profileId,
        "message" to message,
        "nativeAvailable" to nativeAvailable,
        "coreVersion" to coreVersion,
        "down" to 0,
        "up" to 0,
        "connectionCount" to 0
    )

    private fun idle(): Map<String, Any?> = state(
        phase = "idle",
        profileId = null,
        message = "未连接",
        nativeAvailable = false,
        coreVersion = null
    )
}
