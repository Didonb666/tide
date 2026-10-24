// Package core 把「未修改的 mihomo」包成 gomobile 可以绑定的 Android 库。
//
// 它只做四件事：
//   1. 用 mihomo 自己的 parser 解析 YAML（权威校验）；
//   2. 用 hub.ApplyConfig 启动内核（规则、代理、DNS、REST API 全由内核负责）；
//   3. 把 Android VpnService 建好的 TUN fd 交给 mihomo 的 sing_tun 监听器；
//   4. 提供停止与版本查询。
//
// 为什么不用 gomobile 直接绑 mihomo 本体：mihomo 是 main 包，gomobile 不能绑 main。
// 所以这里放一个普通包 core，暴露少量函数，由 gomobile 生成 com.tide.core.Core。
package core

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/netip"
	"strings"
	"sync"

	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub"
	"github.com/metacubex/mihomo/hub/executor"
	LC "github.com/metacubex/mihomo/listener/config"
	"github.com/metacubex/mihomo/listener/sing_tun"
	"github.com/metacubex/mihomo/tunnel"
)

var (
	mu      sync.Mutex
	tun     io.Closer
	running bool
)

// options 由 Kotlin 侧以 JSON 传入。
// 之所以用 JSON 而不是一长串参数：gomobile 对参数个数和类型很挑剔，
// 一个字符串参数最容易演进，也不会因为加字段就要改 Java 签名。
type options struct {
	FD         int    `json:"fd"`
	Stack      string `json:"stack"`
	MTU        int    `json:"mtu"`
	IPv4       string `json:"ipv4"`
	IPv6       string `json:"ipv6"`
	DNS4       string `json:"dns4"`
	DNS6       string `json:"dns6"`
	Controller string `json:"controller"`
	Secret     string `json:"secret"`
}

// Start 是 Kotlin 唯一需要调用的启动函数。
//
//	home       —— 内核工作目录（放 geo 数据、cache.db、规则集缓存），Android 上是 filesDir
//	configYAML —— 用户导入的原始 Clash.Meta 配置文本（不需要先落盘）
//	optionsJSON—— 见上面的 options 结构
//
// 返回 error 会被 gomobile 转成 Java 异常，Kotlin 侧捕获后进入失败态。
func Start(home string, configYAML string, optionsJSON string) (err error) {
	// 内核里有大量 goroutine，一次 panic 就会带走整个 App。边界处兜住。
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("mihomo panic: %v", r)
		}
	}()

	mu.Lock()
	defer mu.Unlock()

	if running {
		return errors.New("mihomo 已在运行")
	}

	var opt options
	if err := json.Unmarshal([]byte(optionsJSON), &opt); err != nil {
		return fmt.Errorf("启动参数不是合法 JSON: %w", err)
	}
	if opt.FD <= 0 {
		return errors.New("TUN fd 无效")
	}
	if opt.MTU <= 0 {
		opt.MTU = 1500
	}

	constant.SetHomeDir(home)

	raw, err := config.UnmarshalRawConfig([]byte(configYAML))
	if err != nil {
		return fmt.Errorf("配置解析失败: %w", err)
	}

	// TUN 由 Android 的 VpnService 创建，禁止内核再去创建设备。
	raw.Tun.Enable = false

	// 控制面只绑本机：Kotlin 传入 127.0.0.1:<随机端口> 与 32 字节随机 secret。
	raw.AllowLan = false
	if opt.Controller != "" {
		raw.ExternalController = opt.Controller
	}
	if opt.Secret != "" {
		raw.Secret = opt.Secret
	}

	cfg, err := config.ParseRawConfig(raw)
	if err != nil {
		return fmt.Errorf("配置构建失败: %w", err)
	}

	// 启动内核：规则、代理、DNS、外部控制器都在这里就绪。
	hub.ApplyConfig(cfg)

	// 再挂 TUN 监听器（与 ClashMetaForAndroid 的做法一致）。
	if err := startTun(opt); err != nil {
		executor.Shutdown()
		return err
	}

	running = true
	return nil
}

// Stop 幂等：重复调用不会报错。
func Stop() (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("mihomo panic on stop: %v", r)
		}
	}()

	mu.Lock()
	defer mu.Unlock()

	return stopLocked()
}

func stopLocked() error {
	var firstErr error

	if tun != nil {
		if err := tun.Close(); err != nil {
			firstErr = err
		}
		tun = nil
	}

	if running {
		executor.Shutdown()
		running = false
	}

	return firstErr
}

// Validate 用内核自己的 parser 做一次权威校验，返回 JSON 字符串：
//
//	{"ok": true, "version": "1.19.33"}
//	{"ok": false, "error": "...", "version": "1.19.33"}
func Validate(home string, configYAML string) string {
	constant.SetHomeDir(home)

	result := map[string]interface{}{
		"ok":      false,
		"version": Version(),
	}

	raw, err := config.UnmarshalRawConfig([]byte(configYAML))
	if err == nil {
		raw.Tun.Enable = false
		_, err = config.ParseRawConfig(raw)
	}
	if err != nil {
		result["error"] = err.Error()
	} else {
		result["ok"] = true
	}

	data, marshalErr := json.Marshal(result)
	if marshalErr != nil {
		return `{"ok":false,"error":"内部错误"}`
	}
	return string(data)
}

// Version 返回编译进库里的 mihomo 版本（由 -ldflags 注入，缺省是源码里的值）。
func Version() string {
	return constant.Version
}

// startTun 把 VpnService 的 fd 交给 mihomo 的 sing-tun 监听器。
//
// 关键点：
//   - AutoRoute / AutoDetectInterface 必须为 false：路由和底层网络由 VpnService 管；
//   - FileDescriptor > 0 时 sing-tun 不会去 open("/dev/net/tun")，直接复用这个 fd；
//   - DNSHijack 里的地址必须是 VpnService 里 setDnsServer 的同一个地址。
func startTun(opt options) error {
	tunOptions := LC.Tun{
		Enable:              true,
		Device:              sing_tun.InterfaceName,
		Stack:               parseStack(opt.Stack),
		DNSHijack:           hijackAddresses(opt.DNS4, opt.DNS6),
		AutoRoute:           false,
		AutoDetectInterface: false,
		MTU:                 uint32(opt.MTU),
		FileDescriptor:      opt.FD,
	}

	if opt.IPv4 != "" {
		prefix, err := netip.ParsePrefix(opt.IPv4)
		if err != nil {
			return fmt.Errorf("IPv4 地址不合法 %q: %w", opt.IPv4, err)
		}
		tunOptions.Inet4Address = []netip.Prefix{prefix}
	}

	if opt.IPv6 != "" {
		prefix, err := netip.ParsePrefix(opt.IPv6)
		if err != nil {
			return fmt.Errorf("IPv6 地址不合法 %q: %w", opt.IPv6, err)
		}
		tunOptions.Inet6Address = []netip.Prefix{prefix}
	}

	listener, err := sing_tun.New(tunOptions, tunnel.Tunnel)
	if err != nil {
		return fmt.Errorf("启动 TUN 失败: %w", err)
	}

	tun = listener
	return nil
}

func parseStack(name string) constant.TUNStack {
	if stack, ok := constant.StackTypeMapping[strings.ToLower(strings.TrimSpace(name))]; ok {
		return stack
	}
	return constant.TunSystem
}

func hijackAddresses(dns4, dns6 string) []string {
	out := make([]string, 0, 2)
	for _, ip := range []string{dns4, dns6} {
		if strings.TrimSpace(ip) == "" {
			continue
		}
		out = append(out, net.JoinHostPort(ip, "53"))
	}
	return out
}
