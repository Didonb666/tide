// android/app/src/main/kotlin/com/tide/tunnel/TunnelSupport.kt
//
// 两个小东西：持久化 + 状态总线。
// 之所以把 secret 单独放 EncryptedSharedPreferences 而不是只留内存：
//   Always-on VPN 在进程被杀后会由系统直接拉起服务（intent == null），
//   此时 Flutter 引擎还没起来，没有人能重新生成 secret。
//   因此 secret 必须可被原生侧读回；用 Keystore 加密落盘是可接受的折中，
//   并且每次用户主动连接都会轮换。

package com.tide.tunnel

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

object Prefs {
    private const val FILE = "tide_tunnel"
    private const val KEY_DESIRED = "desired_connected"
    private const val KEY_PORT = "endpoint_port"
    private const val KEY_SECRET = "endpoint_secret"
    private const val KEY_BACKOFF_UNTIL = "reconnect_not_before"
    private const val KEY_PER_APP_MODE = "per_app_mode"
    private const val KEY_PER_APP_PKGS = "per_app_packages"

    private fun enc(context: Context) = EncryptedSharedPreferences.create(
        context,
        "$FILE.secure",
        MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
    )

    private fun plain(context: Context) =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun setDesiredConnected(context: Context, connected: Boolean) {
        plain(context).edit().putBoolean(KEY_DESIRED, connected).apply()
    }

    fun desiredConnected(context: Context): Boolean =
        plain(context).getBoolean(KEY_DESIRED, false)

    fun saveEndpoint(context: Context, port: Int, secret: String) {
        enc(context).edit().putInt(KEY_PORT, port).putString(KEY_SECRET, secret).apply()
    }

    fun endpoint(context: Context): Pair<Int, String>? {
        val p = enc(context)
        val port = p.getInt(KEY_PORT, 0)
        val secret = p.getString(KEY_SECRET, null)
        return if (port > 0 && !secret.isNullOrEmpty()) port to secret else null
    }

    fun clearEndpoint(context: Context) {
        enc(context).edit().remove(KEY_PORT).remove(KEY_SECRET).apply()
    }

    fun setReconnectNotBefore(context: Context, atMs: Long) {
        plain(context).edit().putLong(KEY_BACKOFF_UNTIL, atMs).apply()
    }

    fun reconnectNotBefore(context: Context): Long =
        plain(context).getLong(KEY_BACKOFF_UNTIL, 0L)

    fun perAppMode(context: Context): String =
        plain(context).getString(KEY_PER_APP_MODE, "none") ?: "none"

    fun perAppPackages(context: Context): Set<String> =
        plain(context).getStringSet(KEY_PER_APP_PKGS, emptySet()) ?: emptySet()
}

/**
 * 状态总线。生产实现建议用 `MutableStateFlow<TunnelState>` + 一个 Binder/本地广播桥，
 * 由 MainActivity 转成 EventChannel 送 Dart。这里只留接口，避免骨架里塞入 DI 框架。
 */
object TunnelStateBus {
    private val listeners = mutableListOf<(TunnelState) -> Unit>()

    fun register(listener: (TunnelState) -> Unit) {
        listeners += listener
    }

    fun unregister(listener: (TunnelState) -> Unit) {
        listeners -= listener
    }

    fun publish(state: TunnelState) {
        listeners.forEach { it(state) }
    }
}
