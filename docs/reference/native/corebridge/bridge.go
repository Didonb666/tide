// native/corebridge/bridge.go
//
// 目标：把**未修改的 mihomo** 包成一个 gomobile 可绑定的库（AAR），
// 让 Kotlin 能在 VPN 进程内直接 start/stop 内核，并把 VpnService 的 TUN fd 交进来。
//
// 这不是 fork。这里只做三件事：
//   1. 复用内核自己的 config parser 做"权威校验"（与 CLI 完全同一条路径）；
//   2. 调用 hub/executor 启停内核；
//   3. 把 fd 注入 TUN 入站（唯一的版本适配点，见 tunfd_android.go）。
//
// 构建（在 native/corebridge 下）：
//   gomobile bind -target=android/arm64,android/arm -androidapi 26 \
//       -javapkg com.tide.core -o ../../android/app/libs/core.aar .
//
// 注意：gomobile bind 要求普通包（非 main），因此 package 名是 core，
// 生成的 Java 类为 com.tide.core.Core。

package core

import (
	"encoding/json"
	"errors"
	"fmt"
	"runtime/debug"
	"sync"
	"time"

	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/log"
)

var (
	mu      sync.Mutex
	running bool
	homeDir string
)

// Start 启动内核。
//
// home:     内核工作目录（等价于 CLI 的 -d），必须包含 geo 数据与 providers 目录；
// configPath: 物化后的 runtime.yaml，必须位于 home 之内（否则需要 SAFE_PATHS）；
// tunFd:    VpnService.establish() 之后 detachFd() 得到的 fd；0 表示不使用 TUN
//
// 返回 error 会被 gomobile 转成 Java 异常，Kotlin 侧据此进入 Failed 状态。
func Start(home, configPath string, tunFd int) (err error) {
	// 内核里有大量 goroutine，任何一个 panic 都会带走整个 App 进程。
	// 在边界处兜住，转成普通错误，让状态机可以走清理路径。
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("mihomo panic: %v\n%s", r, debug.Stack())
		}
	}()

	mu.Lock()
	defer mu.Unlock()

	if running {
		return errors.New("core already running")
	}

	homeDir = home
	constant.SetHome(home) // 让相对路径（providers / geo / cache.db）都以 home 为基准

	cfg, err := config.Parse(configPath)
	if err != nil {
		return fmt.Errorf("parse config: %w", err)
	}

	if tunFd > 0 {
		if err := setTunFileDescriptor(cfg, tunFd); err != nil {
			return fmt.Errorf("inject tun fd: %w", err)
		}
	}

	// 结构化日志走 WS /logs，这里只保证级别正确，避免 stdout 风暴拖慢低端机。
	log.SetLevel(log.INFO)

	executor.Start(cfg, true)
	running = true
	return nil
}

// Stop 关闭内核。可重复调用（幂等），失败不阻断调用方的清理流程。
func Stop() (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("mihomo panic on stop: %v", r)
		}
	}()

	mu.Lock()
	defer mu.Unlock()

	if !running {
		return nil
	}
	executor.Shutdown()
	running = false
	return nil
}

// IsRunning 供 Kotlin 侧在进程重建后判断是否需要修复状态。
func IsRunning() bool {
	mu.Lock()
	defer mu.Unlock()
	return running
}

// ValidateResult 是返回给 Dart 的 JSON 结构，字段与 ValidationReport 对齐。
type ValidateResult struct {
	OK      bool   `json:"ok"`
	Error   string `json:"error,omitempty"`
	Version string `json:"version,omitempty"`
	Elapsed int64  `json:"elapsedMs"`
}

// Validate 用内核 parser 做权威校验。
//
// 这是整个导入链路里最重要的一次"不是我以为，而是内核说了算"的检查：
// Dart 侧的 lint 只负责把错误翻译成人话，最终裁决必须走这里。
// 返回 JSON 字符串（gomobile 对结构体支持有限，string 最稳）。
func Validate(home, configPath string) string {
	started := time.Now()
	res := ValidateResult{Version: Version()}

	defer func() {
		if r := recover(); r != nil {
			res.OK = false
			res.Error = fmt.Sprintf("panic: %v", r)
			res.Elapsed = time.Since(started).Milliseconds()
		}
	}()

	constant.SetHome(home)
	if _, err := config.Parse(configPath); err != nil {
		res.OK = false
		res.Error = err.Error()
	} else {
		res.OK = true
	}

	res.Elapsed = time.Since(started).Milliseconds()
	out, err := json.Marshal(res)
	if err != nil {
		return `{"ok":false,"error":"marshal failed"}`
	}
	return string(out)
}

// Version 返回编译进包里的 mihomo 版本，用于 UI 展示与线上排障。
func Version() string {
	return constant.Version
}

// SupportedProxyTypes 暴露内核支持的 proxy type 白名单，
// 供 Dart 侧 lint 使用 —— 避免把枚举手抄一份然后在升级后悄悄过期。
func SupportedProxyTypes() string {
	// 具体实现：从 constant.ProxyTypeMapping / adapters 注册表导出。
	// 见附录 A：锁定版本后一次性生成 JSON，随包发布。
	return "[]"
}
