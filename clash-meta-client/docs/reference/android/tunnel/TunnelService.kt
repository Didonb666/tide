// android/app/src/main/kotlin/com/tide/tunnel/TunnelService.kt
//
// VpnService + 前台服务 + 状态机执行器。这里只做"执行 Effect"，不做任何状态判断，
// 所有 if/else 都在 TunnelReducer 里（可单测）。
//
// 关键顺序（顺序错了就会踩坑）：
//   startForeground → establish() → detachFd() → Core.start() → 校验 → Connected
//   清理：Core.stop() → close fd（若未交出）→ stopForeground → stopSelf

package com.tide.tunnel

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.IpPrefix
import android.net.Network
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.tide.MainActivity
import com.tide.core.Core
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

class TunnelService : VpnService() {

    companion object {
        private const val TAG = "TideTunnel"
        private const val NOTIF_ID = 0x71DE
        private const val CHANNEL_ID = "tunnel"
        private const val CORE_START_TIMEOUT_MS = 8_000L
        private const val VERIFY_TIMEOUT_MS = 5_000L

        const val ACTION_CONNECT = "com.tide.action.CONNECT"
        const val ACTION_DISCONNECT = "com.tide.action.DISCONNECT"

        const val EXTRA_HOME = "home"
        const val EXTRA_CONFIG = "config"
        const val EXTRA_PORT = "port"
        const val EXTRA_SECRET = "secret"
        const val EXTRA_PROFILE_ID = "profileId"
        const val EXTRA_IPV6 = "ipv6"
        const val EXTRA_MTU = "mtu"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val events = Channel<TunnelEvent>(Channel.UNLIMITED)

    private var state = TunnelState()
    private var pendingFd: Int = -1
    private var pfd: ParcelFileDescriptor? = null
    private var connected = false

    private var home: String = ""
    private var configPath: String = ""
    private var port: Int = 0
    private var secret: String = ""
    private var profileId: String? = null
    private var ipv6: Boolean = true
    private var mtu: Int = 1500

    private val connectivity by lazy { getSystemService(ConnectivityManager::class.java) }
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var underlying: Network? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        scope.launch {
            for (event in events) {
                // 过期会话事件直接丢弃：防止"断开之后又收到上一次的 ready"。
                val sid = event.sessionId
                if (sid != null && state.sessionId != null && sid != state.sessionId) continue
                val transition = TunnelReducer.reduce(state, event)
                state = transition.state
                broadcast()
                transition.effects.forEach { runEffect(it) }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_DISCONNECT) {
            events.trySend(TunnelEvent.Disconnect)
            return START_NOT_STICKY
        }

        // Always-on / 进程重建时 intent 为 null：系统已经授权，不需要也不能再弹 prepare。
        val fromSystem = intent == null
        readExtras(intent)

        // 必须在 5s 内进入前台；放在最前面，失败也要尽量留下可诊断的日志。
        ensureForeground()

        if (fromSystem && configPath.isEmpty()) {
            // 没有可用配置就不要空转，否则 Always-on 会把设备卡在"无网"状态。
            Log.w(TAG, "system-started without config, stop")
            stopSelf()
            return START_NOT_STICKY
        }

        val session = UUID.randomUUID().toString()
        if (prepare(this) == null) {
            events.trySend(TunnelEvent.Connect(session))
            events.trySend(TunnelEvent.PermissionResult(session, granted = true))
        } else {
            // 走到这里说明是用户点击启动但授权已被撤销（例如从设置里关闭了 VPN）。
            events.trySend(
                TunnelEvent.Connect(session)
            )
            events.trySend(TunnelEvent.PermissionResult(session, granted = false))
        }
        return START_STICKY
    }

    // ---------------------------------------------------------------- effects

    private fun runEffect(effect: TunnelEffect) {
        when (effect) {
            TunnelEffect.RequestPermission -> {
                // 授权流程由 Activity 侧完成（VpnService.prepare 需要 startActivityForResult）。
                // Service 只负责"如果已授权就继续"，未授权时由 UI 引导。
                val sid = state.sessionId ?: return
                if (prepare(this) == null) {
                    events.trySend(TunnelEvent.PermissionResult(sid, granted = true))
                } else {
                    events.trySend(TunnelEvent.PermissionResult(sid, granted = false))
                }
            }

            TunnelEffect.StartForeground -> {
                ensureForeground()
                events.trySend(TunnelEvent.ServiceReady(state.sessionId ?: return))
            }

            TunnelEffect.EstablishTun -> establishTun()

            is TunnelEffect.HandoffFd -> {
                pendingFd = effect.fd
                // fd 所有权已交给内核路径，Kotlin 不再 close 这个 pfd。
                pfd = null
                events.trySend(TunnelEvent.FdHandedOff(state.sessionId ?: return))
            }

            TunnelEffect.StartCore -> startCore()

            TunnelEffect.VerifyCore -> verifyCore()

            TunnelEffect.StopCore -> {
                runCatching { Core.stop() }.onFailure { Log.w(TAG, "core stop failed", it) }
                disconnectNetworkCallback()
                connected = false
            }

            TunnelEffect.CloseTun -> {
                runCatching { pfd?.close() }
                pfd = null
                pendingFd = -1
            }

            TunnelEffect.RefreshNotification -> notifyState()

            TunnelEffect.StopSelf -> {
                ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
                events.trySend(TunnelEvent.CleanupDone)
                stopSelf()
            }

            is TunnelEffect.PersistDesired -> {
                Prefs.setDesiredConnected(this, effect.desiredConnected)
                if (!effect.desiredConnected) Prefs.clearEndpoint(this)
            }

            is TunnelEffect.Backoff -> Prefs.setReconnectNotBefore(
                this,
                System.currentTimeMillis() + effect.millis,
            )
        }
    }

    private fun establishTun() {
        val sid = state.sessionId ?: return
        try {
            val builder = Builder()
                .setSession("Tide")
                .setMtu(mtu)
                .addAddress("172.19.0.1", 30)
                .addRoute("0.0.0.0", 0)
                .setBlocking(false) // 严格模式才 true：内核挂掉会全设备断网
                .setMetered(false)
                .setConfigureIntent(openAppIntent())
                .setDnsServer("172.19.0.2")

            // 自己不进隧道，避免 DNS/回环被卷进 TUN。
            runCatching { builder.addDisallowedApplication(packageName) }

            if (ipv6) {
                builder.addAddress("fdfe:dcba:9876::1", 126)
                builder.addRoute("::", 0)
                builder.setDnsServer("fdfe:dcba:9876::2")
            }

            // 绕过局域网：API 33+ 有原生 excludeRoute；更低版本由 Dart 侧注入 prelude 规则。
            if (Build.VERSION.SDK_INT >= 33) {
                LAN_PREFIXES.forEach { builder.excludeRoute(it) }
            }

            applyPerAppPolicy(builder)

            val descriptor = builder.establish()
                ?: throw IllegalStateException("establish() returned null")
            // detachFd 之后 descriptor 即失效：绝不能再次 close，否则 fd 编号被回收复用，
            // 会出现"连上了但所有流量黑洞"这种极难定位的 bug。
            val fd = descriptor.detachFd()
            pfd = null
            if (fd <= 0) throw IllegalStateException("invalid fd: $fd")

            registerNetworkCallback()
            events.trySend(TunnelEvent.TunEstablished(sid, fd))
        } catch (t: Throwable) {
            Log.e(TAG, "establish tun failed", t)
            events.trySend(TunnelEvent.TunFailed(sid, mapTunError(t)))
        }
    }

    private fun startCore() {
        val sid = state.sessionId ?: return
        scope.launch(Dispatchers.IO) {
            try {
                withTimeout(CORE_START_TIMEOUT_MS) {
                    Core.start(home, configPath, pendingFd) // gomobile: 失败抛异常
                }
                events.trySend(TunnelEvent.CoreReady(sid))
            } catch (t: Throwable) {
                Log.e(TAG, "core start failed", t)
                events.trySend(
                    TunnelEvent.CoreFailed(
                        sid,
                        TunnelError("E_CORE_START_TIMEOUT", "内核启动失败：${t.message}", true, t),
                    ),
                )
            }
        }
    }

    private fun verifyCore() {
        val sid = state.sessionId ?: return
        scope.launch(Dispatchers.IO) {
            try {
                val version = withTimeout(VERIFY_TIMEOUT_MS) { httpGet("/version") }
                val rules = withTimeout(VERIFY_TIMEOUT_MS) { httpGet("/rules") }
                if (version.isNullOrBlank() || !rules.contains("\"rules\"")) {
                    throw IllegalStateException("unexpected payload")
                }
                Prefs.saveEndpoint(this@TunnelService, port, secret)
                events.trySend(TunnelEvent.VerifyOk(sid))
            } catch (t: Throwable) {
                events.trySend(
                    TunnelEvent.VerifyFailed(
                        sid,
                        TunnelError("E_VERIFY_FAILED", "内核未在预期时间内就绪：${t.message}", true, t),
                    ),
                )
            }
        }
    }

    private fun httpGet(path: String): String? {
        val url = URL("http://127.0.0.1:$port$path")
        val conn = url.openConnection() as HttpURLConnection
        return try {
            conn.requestMethod = "GET"
            conn.connectTimeout = 1500
            conn.readTimeout = 1500
            conn.setRequestProperty("Authorization", "Bearer $secret")
            if (conn.responseCode !in 200..299) {
                throw IllegalStateException("HTTP ${conn.responseCode} on $path")
            }
            conn.inputStream.bufferedReader().use { it.readText() }
        } finally {
            conn.disconnect()
        }
    }

    // -------------------------------------------------------------- vpn hooks

    override fun onRevoke() {
        Log.w(TAG, "vpn revoked")
        events.trySend(TunnelEvent.Revoked)
        super.onRevoke()
    }

    override fun onDestroy() {
        events.trySend(TunnelEvent.Disconnect)
        disconnectNetworkCallback()
        scope.launch {
            runCatching { Core.stop() }
        }
        super.onDestroy()
    }

    // ------------------------------------------------------------ notification

    private fun ensureForeground() {
        val type = if (Build.VERSION.SDK_INT >= 34) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            0
        }
        ServiceCompat.startForeground(this, NOTIF_ID, buildNotification(), type)
    }

    private fun buildNotification(): Notification {
        val disconnect = PendingIntent.getService(
            this,
            1,
            Intent(this, TunnelService::class.java).setAction(ACTION_DISCONNECT),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val title = when (state.phase) {
            TunnelPhase.CONNECTED -> "已连接 · 规则模式"
            TunnelPhase.VERIFYING, TunnelPhase.CORE_STARTING -> "正在启动内核"
            TunnelPhase.FAILED -> "已断开（${state.error?.code ?: "未知错误"}）"
            else -> "正在连接"
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(com.tide.R.drawable.ic_stat_tide)
            .setContentTitle(title)
            .setContentText(state.profileId?.let { "配置 $it" } ?: "未选择配置")
            .setContentIntent(openAppIntent())
            .setOngoing(state.phase != TunnelPhase.FAILED)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(0, "断开", disconnect)
            .build()
    }

    private fun notifyState() {
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(NOTIF_ID, buildNotification())
    }

    private fun createChannel() {
        val nm = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(CHANNEL_ID, "隧道状态", NotificationManager.IMPORTANCE_LOW).apply {
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        nm.createNotificationChannel(channel)
    }

    private fun openAppIntent(): PendingIntent = PendingIntent.getActivity(
        this,
        0,
        Intent(this, MainActivity::class.java),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    // ---------------------------------------------------------------- network

    private fun registerNetworkCallback() {
        if (networkCallback != null) return
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                underlying = network
                // 切网后必须重新绑定，否则隧道会"假死"：连接在、流量不动。
                runCatching { setUnderlyingNetworks(arrayOf(network)) }
            }

            override fun onLost(network: Network) {
                if (underlying == network) {
                    underlying = null
                    runCatching { setUnderlyingNetworks(null) }
                }
            }
        }
        networkCallback = cb
        runCatching { connectivity.registerDefaultNetworkCallback(cb) }
    }

    private fun disconnectNetworkCallback() {
        networkCallback?.let { cb -> runCatching { connectivity.unregisterNetworkCallback(cb) } }
        networkCallback = null
    }

    // ------------------------------------------------------------------ extras

    private fun readExtras(intent: Intent?) {
        intent ?: return
        home = intent.getStringExtra(EXTRA_HOME) ?: home
        configPath = intent.getStringExtra(EXTRA_CONFIG) ?: configPath
        port = intent.getIntExtra(EXTRA_PORT, port)
        secret = intent.getStringExtra(EXTRA_SECRET) ?: secret
        profileId = intent.getStringExtra(EXTRA_PROFILE_ID) ?: profileId
        ipv6 = intent.getBooleanExtra(EXTRA_IPV6, ipv6)
        mtu = intent.getIntExtra(EXTRA_MTU, mtu)
        if (home.isNotEmpty() && configPath.isNotEmpty() && port > 0) {
            Prefs.saveEndpoint(this, port, secret)
        }
    }

    private fun applyPerAppPolicy(builder: Builder) {
        val mode = Prefs.perAppMode(this) // none / allow / disallow
        val packages = Prefs.perAppPackages(this)
        if (packages.isEmpty()) return
        packages.forEach { pkg ->
            runCatching {
                if (mode == "allow") builder.addAllowedApplication(pkg)
                else builder.addDisallowedApplication(pkg)
            }
        }
    }

    private fun mapTunError(t: Throwable): TunnelError = when (t) {
        is IllegalStateException -> TunnelError(
            "E_VPN_ALREADY_ACTIVE",
            "另一个 VPN 正在运行，或 TUN 建立失败",
            true,
            t,
        )
        is SecurityException -> TunnelError("E_VPN_PERMISSION_DENIED", "VPN 权限已被撤销", false, t)
        else -> TunnelError("E_TUN_ESTABLISH_FAILED", "TUN 建立失败：${t.message}", true, t)
    }

    private fun broadcast() {
        // 用 LocalBroadcast / 应用内 Flow 替换；此处仅示意状态出口。
        TunnelStateBus.publish(state)
    }

    private val LAN_PREFIXES: List<IpPrefix>
        get() = listOf(
            IpPrefix("10.0.0.0/8"),
            IpPrefix("172.16.0.0/12"),
            IpPrefix("192.168.0.0/16"),
            IpPrefix("fc00::/7"),
            IpPrefix("fe80::/10"),
        )
}
