package com.tide.tide

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter 与 Android 原生之间的唯一通道。
 *
 * 第二阶段起，connect 不再只是"演示一个状态"，而是：
 *   1. 检查/申请 VPN 权限（VpnService.prepare）；
 *   2. 启动 TunnelService（前台服务）；
 *   3. 由服务建立 TUN、把 fd 交给 mihomo；
 *   4. 状态通过 TunnelBus → EventChannel 持续推给 Dart。
 *
 * 通道协议（与 lib/core/tunnel/method_channel_tunnel.dart 对应）：
 *   isAvailable()  -> Boolean
 *   getState()     -> Map
 *   connect({profileId, config, secret, port, ipv6}) -> Map
 *   disconnect()   -> Map
 *   coreVersion()  -> String?
 */
class TunnelChannel(
    private val activity: Activity,
    messenger: BinaryMessenger
) {

    companion object {
        private const val REQUEST_VPN = 0x5601
        private const val REQUEST_NOTIFICATION = 0x5602
    }

    private val methodChannel = MethodChannel(messenger, "tide/tunnel")
    private val eventChannel = EventChannel(messenger, "tide/tunnel/events")

    private var sink: EventChannel.EventSink? = null
    private var pending: PendingStart? = null

    private data class PendingStart(
        val config: String,
        val profileId: String?,
        val secret: String,
        val port: Int,
        val ipv6: Boolean
    )

    private val listener: (Map<String, Any?>) -> Unit = { state ->
        activity.runOnUiThread { sink?.success(state) }
    }

    fun attach() {
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sink = events
                events?.success(TunnelBus.last)
                TunnelBus.addListener(listener)
            }

            override fun onCancel(arguments: Any?) {
                TunnelBus.removeListener(listener)
                sink = null
            }
        })

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(true)
                "getState" -> result.success(TunnelBus.last)
                "connect" -> {
                    val started = startTunnel(
                        config = call.argument<String>("config").orEmpty(),
                        profileId = call.argument<String>("profileId"),
                        secret = call.argument<String>("secret").orEmpty(),
                        port = call.argument<Int>("port") ?: 0,
                        ipv6 = call.argument<Boolean>("ipv6") ?: true
                    )
                    if (started) {
                        result.success(TunnelBus.last)
                    } else {
                        result.success(
                            TunnelBus.state("failed", null, "配置为空", false, null)
                        )
                    }
                }
                "disconnect" -> {
                    launchService(
                        PendingStart("", null, "", 0, true),
                        stopOnly = true
                    )
                    result.success(TunnelBus.state("idle", null, "已断开", false, null))
                }
                "coreVersion" -> result.success(runCatching { CoreVersion.get() }.getOrNull())
                else -> result.notImplemented()
            }
        }
    }

    /** MainActivity 转发系统授权结果。 */
    fun onActivityResult(requestCode: Int, resultCode: Int) {
        if (requestCode != REQUEST_VPN) return

        val request = pending
        pending = null

        if (request == null) return

        if (resultCode == Activity.RESULT_OK) {
            launchService(request)
        } else {
            TunnelBus.publish(
                TunnelBus.state(
                    "failed",
                    request.profileId,
                    "VPN 授权被拒绝，无法建立隧道",
                    false,
                    null
                )
            )
        }
    }

    private fun startTunnel(
        config: String,
        profileId: String?,
        secret: String,
        port: Int,
        ipv6: Boolean
    ): Boolean {
        if (config.isBlank()) {
            TunnelBus.publish(
                TunnelBus.state("failed", profileId, "配置为空", false, null)
            )
            return false
        }

        val request = PendingStart(config, profileId, secret, port, ipv6)

        // Android 13+ 通知权限：不申请的话前台服务照跑，但通知栏看不到。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            activity.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
            android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            activity.requestPermissions(
                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_NOTIFICATION
            )
        }

        // prepare() 返回非 null 表示用户还没授权，需要弹系统对话框。
        val intent: Intent? = VpnService.prepare(activity)
        if (intent != null) {
            pending = request
            TunnelBus.publish(
                TunnelBus.state("connecting", profileId, "等待 VPN 授权…", false, null)
            )
            activity.startActivityForResult(intent, REQUEST_VPN)
            return true
        }

        launchService(request)
        return true
    }

    private fun launchService(request: PendingStart, stopOnly: Boolean = false) {
        val intent = Intent(activity, TunnelService::class.java).apply {
            action = if (stopOnly) TunnelService.ACTION_STOP else TunnelService.ACTION_START
            if (!stopOnly) {
                putExtra(TunnelService.EXTRA_CONFIG, request.config)
                putExtra(TunnelService.EXTRA_PROFILE, request.profileId)
                putExtra(TunnelService.EXTRA_SECRET, request.secret)
                putExtra(TunnelService.EXTRA_PORT, request.port)
                putExtra(TunnelService.EXTRA_IPV6, request.ipv6)
            }
        }

        // minSdk = 26，系统总是要求用 startForegroundService 启动会进前台的 service。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.startForegroundService(intent)
        } else {
            activity.startService(intent)
        }
    }
}

/** 单独包一层，避免 AAR 还没下载时 TunnelChannel 直接编译失败（便于排错）。 */
private object CoreVersion {
    fun get(): String? = com.tide.core.Core.version()
}
