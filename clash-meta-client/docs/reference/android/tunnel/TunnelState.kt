// android/app/src/main/kotlin/com/tide/tunnel/TunnelState.kt
//
// 纯状态机：不碰 Android API，因此可以用 JVM 单测把 13 个 phase × N 个事件全部覆盖。
// 这是整个 Android 侧最该被测试覆盖的文件 —— 隧道出问题 90% 是状态迁移写错，
// 而不是 VpnService 用错。
//
// 设计约束（见架构文档 §6.1）：
//   1. 迁移只可能由 TunnelReducer 产生，Service 只负责执行 Effect；
//   2. Connect 的"授权成功"与"已授权"合并成同一个事件，避免两条路径分叉；
//   3. Stopping 是唯一的收尾状态，Failed / Revoked 都必须先到 Stopping 再到 Idle，
//      保证"关内核 → 关 fd → 撤通知 → stopSelf"的顺序不会被跳过。

package com.tide.tunnel

enum class TunnelPhase {
    IDLE,
    REQUESTING_PERMISSION,
    PERMISSION_DENIED,
    STARTING_SERVICE,
    ESTABLISHING_TUN,
    HANDING_OFF_FD,
    CORE_STARTING,
    VERIFYING,
    CONNECTED,
    RECONFIGURING,
    STOPPING,
    REVOKED,
    FAILED,
    ;

    val isEngaged: Boolean
        get() = this == CONNECTED || this == STARTING_SERVICE || this == ESTABLISHING_TUN ||
            this == HANDING_OFF_FD || this == CORE_STARTING || this == VERIFYING ||
            this == RECONFIGURING

    val isBusy: Boolean
        get() = this == STARTING_SERVICE || this == ESTABLISHING_TUN || this == HANDING_OFF_FD ||
            this == CORE_STARTING || this == VERIFYING || this == RECONFIGURING ||
            this == STOPPING
}

enum class PrepareState { NOT_REQUESTED, GRANTED, DENIED, UNSUPPORTED }

enum class ServiceState { STOPPED, STARTING, RUNNING, FOREGROUND }

enum class TunFdState { NONE, ESTABLISHED, HANDED_OFF, INVALID }

enum class CoreState { STOPPED, STARTING, RUNNING, UNREACHABLE }

data class TunnelError(
    val code: String,
    val message: String,
    val recoverable: Boolean = false,
    val cause: Throwable? = null,
)

data class TunnelState(
    val phase: TunnelPhase = TunnelPhase.IDLE,
    val prepare: PrepareState = PrepareState.NOT_REQUESTED,
    val service: ServiceState = ServiceState.STOPPED,
    val tunFd: TunFdState = TunFdState.NONE,
    val core: CoreState = CoreState.STOPPED,
    val sessionId: String? = null,
    val profileId: String? = null,
    val error: TunnelError? = null,
    val sinceMs: Long = 0L,
) {
    val isConnected: Boolean get() = phase == TunnelPhase.CONNECTED

    /** Connect 按钮是否可用；UI 直接读它，不要自己推导。 */
    val canConnect: Boolean
        get() = phase == TunnelPhase.IDLE || phase == TunnelPhase.FAILED ||
            phase == TunnelPhase.PERMISSION_DENIED || phase == TunnelPhase.REVOKED

    val canDisconnect: Boolean get() = phase.isEngaged
}

/** 事件。带 sessionId 的事件在 Service 层会被过滤掉过期会话。 */
sealed interface TunnelEvent {
    val sessionId: String?

    data class Connect(override val sessionId: String) : TunnelEvent
    data class PermissionResult(override val sessionId: String, val granted: Boolean) : TunnelEvent
    data class ServiceReady(override val sessionId: String) : TunnelEvent
    data class TunEstablished(override val sessionId: String, val fd: Int) : TunnelEvent
    data class TunFailed(override val sessionId: String, val error: TunnelError) : TunnelEvent
    data class FdHandedOff(override val sessionId: String) : TunnelEvent
    data class FdRejected(override val sessionId: String, val error: TunnelError) : TunnelEvent
    data class CoreReady(override val sessionId: String) : TunnelEvent
    data class CoreFailed(override val sessionId: String, val error: TunnelError) : TunnelEvent
    data class VerifyOk(override val sessionId: String) : TunnelEvent
    data class VerifyFailed(override val sessionId: String, val error: TunnelError) : TunnelEvent
    data class CoreExited(override val sessionId: String, val code: Int?) : TunnelEvent
    data class ApplyConfig(override val sessionId: String) : TunnelEvent
    data class ApplyConfigOk(override val sessionId: String) : TunnelEvent
    data class ApplyConfigFailed(override val sessionId: String, val error: TunnelError) : TunnelEvent

    data object Disconnect : TunnelEvent {
        override val sessionId: String? = null
    }

    data object Revoked : TunnelEvent {
        override val sessionId: String? = null
    }

    data object CleanupDone : TunnelEvent {
        override val sessionId: String? = null
    }
}

/** 副作用。Reducer 只描述"要做什么"，Service 决定"怎么做"。 */
sealed interface TunnelEffect {
    /** 弹系统授权（可能不需要，因为已授权时 prepare() 返回 null）。 */
    data object RequestPermission : TunnelEffect

    /** 5 秒内必须调用 startForeground，否则 ANR/被杀。 */
    data object StartForeground : TunnelEffect

    data object EstablishTun : TunnelEffect

    /** fd 所有权交给 Go，之后 Kotlin 侧不得 close。 */
    data class HandoffFd(val fd: Int) : TunnelEffect

    data object StartCore : TunnelEffect

    /** GET /version + /configs + /rules 三道校验。 */
    data object VerifyCore : TunnelEffect

    data object StopCore : TunnelEffect

    data object CloseTun : TunnelEffect

    /** 只更新通知文案/按钮，不算状态迁移。 */
    data object RefreshNotification : TunnelEffect

    /** 停止前台并 stopSelf（最后一个副作用）。 */
    data object StopSelf : TunnelEffect

    /** 持久化"用户想要的最终状态"，供进程被杀后恢复 / Always-on 使用。 */
    data class PersistDesired(val desiredConnected: Boolean) : TunnelEffect

    /** onRevoke 之后禁止立即自动重连，避免和系统打架。 */
    data class Backoff(val millis: Long) : TunnelEffect
}

data class Transition(val state: TunnelState, val effects: List<TunnelEffect>)

object TunnelReducer {

    fun reduce(state: TunnelState, event: TunnelEvent): Transition = when (event) {

        is TunnelEvent.Connect -> {
            if (!state.canConnect) {
                // 重复点击 / 忙碌中点击：忽略，但要让 UI 有反馈（Service 层发一次 tick）。
                Transition(state, emptyList())
            } else {
                Transition(
                    state.copy(
                        phase = TunnelPhase.REQUESTING_PERMISSION,
                        sessionId = event.sessionId,
                        error = null,
                    ),
                    listOf(TunnelEffect.RequestPermission),
                )
            }
        }

        is TunnelEvent.PermissionResult -> {
            if (state.phase != TunnelPhase.REQUESTING_PERMISSION) return ignore(state)
            if (!event.granted) {
                Transition(
                    state.copy(
                        phase = TunnelPhase.PERMISSION_DENIED,
                        prepare = PrepareState.DENIED,
                        error = TunnelError("E_VPN_PERMISSION_DENIED", "VPN 授权被拒绝"),
                    ),
                    emptyList(),
                )
            } else {
                Transition(
                    state.copy(
                        phase = TunnelPhase.STARTING_SERVICE,
                        prepare = PrepareState.GRANTED,
                        service = ServiceState.STARTING,
                    ),
                    listOf(TunnelEffect.StartForeground),
                )
            }
        }

        is TunnelEvent.ServiceReady -> {
            if (state.phase != TunnelPhase.STARTING_SERVICE) return ignore(state)
            Transition(
                state.copy(phase = TunnelPhase.ESTABLISHING_TUN, service = ServiceState.FOREGROUND),
                listOf(TunnelEffect.EstablishTun),
            )
        }

        is TunnelEvent.TunEstablished -> {
            if (state.phase != TunnelPhase.ESTABLISHING_TUN) return ignore(state)
            Transition(
                state.copy(phase = TunnelPhase.HANDING_OFF_FD, tunFd = TunFdState.ESTABLISHED),
                listOf(TunnelEffect.HandoffFd(event.fd)),
            )
        }

        is TunnelEvent.TunFailed -> fail(state, event.error)

        is TunnelEvent.FdHandedOff -> {
            if (state.phase != TunnelPhase.HANDING_OFF_FD) return ignore(state)
            Transition(
                state.copy(
                    phase = TunnelPhase.CORE_STARTING,
                    tunFd = TunFdState.HANDED_OFF,
                    core = CoreState.STARTING,
                ),
                listOf(TunnelEffect.StartCore),
            )
        }

        is TunnelEvent.FdRejected -> fail(state, event.error)

        is TunnelEvent.CoreReady -> {
            if (state.phase != TunnelPhase.CORE_STARTING) return ignore(state)
            Transition(
                state.copy(phase = TunnelPhase.VERIFYING, core = CoreState.RUNNING),
                listOf(TunnelEffect.VerifyCore),
            )
        }

        is TunnelEvent.CoreFailed -> fail(state, event.error)

        is TunnelEvent.VerifyOk -> {
            if (state.phase != TunnelPhase.VERIFYING) return ignore(state)
            Transition(
                state.copy(phase = TunnelPhase.CONNECTED, error = null, sinceMs = now()),
                listOf(
                    TunnelEffect.PersistDesired(true),
                    TunnelEffect.RefreshNotification,
                ),
            )
        }

        is TunnelEvent.VerifyFailed -> fail(state, event.error)

        is TunnelEvent.ApplyConfig -> {
            if (state.phase != TunnelPhase.CONNECTED) return ignore(state)
            Transition(state.copy(phase = TunnelPhase.RECONFIGURING), emptyList())
        }

        is TunnelEvent.ApplyConfigOk -> {
            if (state.phase != TunnelPhase.RECONFIGURING) return ignore(state)
            Transition(state.copy(phase = TunnelPhase.CONNECTED), listOf(TunnelEffect.RefreshNotification))
        }

        is TunnelEvent.ApplyConfigFailed -> fail(state, event.error)

        is TunnelEvent.CoreExited -> fail(
            state,
            TunnelError(
                code = "E_CORE_EXITED",
                message = "内核已退出（code=${event.code}）",
                recoverable = true,
            ),
        )

        TunnelEvent.Disconnect -> {
            if (state.phase == TunnelPhase.IDLE || state.phase == TunnelPhase.STOPPING) {
                ignore(state)
            } else {
                Transition(
                    state.copy(phase = TunnelPhase.STOPPING, sinceMs = now()),
                    listOf(
                        TunnelEffect.PersistDesired(false),
                        TunnelEffect.StopCore,
                        TunnelEffect.CloseTun,
                        TunnelEffect.StopSelf,
                    ),
                )
            }
        }

        TunnelEvent.Revoked -> Transition(
            state.copy(
                phase = TunnelPhase.REVOKED,
                error = TunnelError("E_VPN_REVOKED", "VPN 权限被系统或其他应用收回", recoverable = true),
                sinceMs = now(),
            ),
            listOf(
                TunnelEffect.PersistDesired(false),
                TunnelEffect.Backoff(30_000),
                TunnelEffect.StopCore,
                TunnelEffect.CloseTun,
                TunnelEffect.StopSelf,
            ),
        )

        TunnelEvent.CleanupDone -> {
            val cleanable = state.phase == TunnelPhase.STOPPING ||
                state.phase == TunnelPhase.REVOKED ||
                state.phase == TunnelPhase.FAILED
            if (!cleanable) {
                ignore(state)
            } else {
                Transition(
                    state.copy(
                        phase = TunnelPhase.IDLE,
                        service = ServiceState.STOPPED,
                        tunFd = TunFdState.NONE,
                        core = CoreState.STOPPED,
                        sessionId = null,
                        sinceMs = now(),
                        // error 故意保留：回到 Idle 后 UI 仍要能显示"上次失败原因"。
                    ),
                    emptyList(),
                )
            }
        }
    }

    /**
     * 任何失败都先进入 FAILED，再走与 Disconnect 完全相同的清理路径
     * （停内核 → 关 fd → 撤通知 → stopSelf），避免出现"状态说断了但服务还在跑"。
     */
    private fun fail(state: TunnelState, error: TunnelError): Transition = Transition(
        state.copy(phase = TunnelPhase.FAILED, error = error, sinceMs = now()),
        listOf(
            TunnelEffect.PersistDesired(false),
            TunnelEffect.StopCore,
            TunnelEffect.CloseTun,
            TunnelEffect.RefreshNotification,
            TunnelEffect.StopSelf,
        ),
    )

    private fun ignore(state: TunnelState): Transition = Transition(state, emptyList())

    private fun now(): Long = System.currentTimeMillis()
}
