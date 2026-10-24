package com.fstool.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.util.Log
import com.tide.core.Core
import org.json.JSONObject

/**
 * 真正的 VpnService。
 *
 * 流程：
 *   startForeground → Builder.establish()（TUN 设备由系统创建）
 *   → detachFd() → Core.start(home, yaml, optionsJson)
 *   → 内核在同一个进程里接管这个 fd
 *
 * 几个容易踩死的点（都已处理）：
 *   1. establish() 必须在 startForeground 之后 5 秒内完成，否则系统会杀服务；
 *   2. detachFd() 之后绝不能再 close 那个 ParcelFileDescriptor；
 *   3. 必须 addDisallowedApplication(自己)，否则内核的出站流量会被自己的 TUN 再抓一遍，形成回环；
 *   4. TUN 的地址/MTU/DNS 必须和传给内核的参数完全一致。
 */
class TunnelService : VpnService() {

    companion object {
        private const val TAG = "TideTunnel"
        private const val CHANNEL_ID = "tunnel"
        private const val NOTIFICATION_ID = 0x71DE

        const val ACTION_START = "com.tide.action.START"
        const val ACTION_STOP = "com.tide.action.STOP"

        const val EXTRA_CONFIG = "config"
        const val EXTRA_PROFILE = "profileId"
        const val EXTRA_SECRET = "secret"
        const val EXTRA_PORT = "port"
        const val EXTRA_IPV6 = "ipv6"

        // 这些值必须与 native 侧 buildOptions() 完全一致
        private const val TUN_IPV4 = "172.19.0.1"
        private const val TUN_IPV4_PREFIX = "172.19.0.1/30"
        private const val TUN_DNS4 = "172.19.0.2"
        private const val TUN_IPV6 = "fdfe:dcba:9876::1"
        private const val TUN_IPV6_PREFIX = "fdfe:dcba:9876::1/126"
        private const val TUN_DNS6 = "fdfe:dcba:9876::2"
        private const val TUN_MTU = 1500
    }

    @Volatile
    private var stopping = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null || intent.action == ACTION_STOP) {
            // 即使只是"停止"，也要先 startForeground：
            // 如果这个服务是被 startForegroundService 拉起来的，5 秒内不调用它会被系统判为 ANR。
            createChannel()
            startAsForeground("正在断开…")
            shutdown()
            return START_NOT_STICKY
        }

        createChannel()
        startAsForeground("正在连接…")

        val config = intent.getStringExtra(EXTRA_CONFIG).orEmpty()
        val profileId = intent.getStringExtra(EXTRA_PROFILE)
        val secret = intent.getStringExtra(EXTRA_SECRET).orEmpty()
        val port = intent.getIntExtra(EXTRA_PORT, 0)
        val ipv6 = intent.getBooleanExtra(EXTRA_IPV6, true)

        if (config.isBlank()) {
            publishFailed(profileId, "配置内容为空")
            return START_NOT_STICKY
        }

        TunnelBus.publish(
            TunnelBus.state("connecting", profileId, "正在建立隧道…", false, null)
        )

        Thread {
            connect(config, profileId, secret, port, ipv6)
        }.start()

        return START_NOT_STICKY
    }

    private fun connect(
        config: String,
        profileId: String?,
        secret: String,
        port: Int,
        ipv6: Boolean
    ) {
        try {
            val builder = Builder()
                .setSession("Tide")
                .setMtu(TUN_MTU)
                .addAddress(TUN_IPV4, 30)
                .addRoute("0.0.0.0", 0)
                .addDnsServer(TUN_DNS4)
                .setBlocking(false)
                .setMetered(false)

            // 关键：把自己排除在 VPN 之外，内核的出站 socket 才不会被 TUN 二次捕获。
            runCatching { builder.addDisallowedApplication(packageName) }

            if (ipv6) {
                builder.addAddress(TUN_IPV6, 126)
                builder.addRoute("::", 0)
                builder.addDnsServer(TUN_DNS6)
            }

            val descriptor = builder.establish()
                ?: throw IllegalStateException("VpnService.establish() 返回 null")

            // 交出 fd 所有权。之后不能再 pfd.close()，否则 fd 号会被复用。
            val fd = descriptor.detachFd()

            val options = JSONObject()
                .put("fd", fd)
                .put("stack", "gvisor")
                .put("mtu", TUN_MTU)
                .put("ipv4", TUN_IPV4_PREFIX)
                .put("ipv6", if (ipv6) TUN_IPV6_PREFIX else "")
                .put("dns4", TUN_DNS4)
                .put("dns6", if (ipv6) TUN_DNS6 else "")
                .put("controller", "127.0.0.1:$port")
                .put("secret", secret)

            // 阻塞调用：解析配置 + 启动内核 + 挂 TUN，通常 0.5~3 秒。
            Core.start(filesDir.absolutePath, config, options.toString())

            val version = runCatching { Core.version() }.getOrNull()
            TunnelBus.publish(
                TunnelBus.state("connected", profileId, "已连接", true, version)
            )
            updateNotification("已连接 · 规则模式")
        } catch (t: Throwable) {
            Log.e(TAG, "启动隧道失败", t)
            publishFailed(profileId, t.message ?: t.javaClass.simpleName)
        }
    }

    private fun publishFailed(profileId: String?, reason: String) {
        TunnelBus.publish(
            TunnelBus.state("failed", profileId, reason, false, null)
        )
        // 保留 failed 状态给 UI 展示，不要把状态改回 idle。
        shutdown(resetState = false)
    }

    private fun shutdown(resetState: Boolean = true) {
        if (stopping) return
        stopping = true

        runCatching { Core.stop() }
            .onFailure { Log.w(TAG, "停止内核失败", it) }

        if (resetState) {
            TunnelBus.publish(TunnelBus.state("idle", null, "已断开", false, null))
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onRevoke() {
        Log.w(TAG, "VPN 权限被系统或其它应用收回")
        shutdown()
        super.onRevoke()
    }

    override fun onDestroy() {
        runCatching { Core.stop() }
        super.onDestroy()
    }

    // ------------------------------------------------------------ notification

    private fun createChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "隧道状态",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun startAsForeground(text: String) {
        val notification = buildNotification(text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(text: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(text))
    }

    private fun buildNotification(text: String): Notification {
        val disconnect = PendingIntent.getService(
            this,
            1,
            Intent(this, TunnelService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_tide)
            .setContentTitle("Tide")
            .setContentText(text)
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "断开",
                disconnect
            )
            .build()
    }
}
