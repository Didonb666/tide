// Package core 把 mihomo 包成 gomobile 可以绑定的 Android 库。
//
// 它只做四件事：
//   1. 用 mihomo 自己的 parser 解析 YAML（权威校验）；
//   2. 用 hub.ApplyConfig 启动内核（规则、代理、DNS、REST API 全由内核负责）；
//   3. 把 Android VpnService 建好的 TUN fd 交给 mihomo 的 sing_tun 监听器；
//   4. 提供停止与版本查询。
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

	"github.com/metacubex/mihomo/component/process"
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
func Start(home string, configYAML string, optionsJSON string) (err error) {
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

	// 关键：关闭进程/应用名查找。
	// Android 上普通 App 无权读取 /data/system/packages.xml，
	// 一旦规则里出现 PROCESS-NAME / 分应用相关匹配，内核就会去读它并失败。
	// （TUN 的 buildAndroidRules 已在内核源码里打补丁跳过，这里再兜一层。）
	raw.FindProcessMode = process.FindProcessOff

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

	// 再挂 TUN 监听器。
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

// Validate 用内核自己的 parser 做一次权威校验，返回 JSON 字符串。
func Validate(home string, configYAML string) string {
	constant.SetHomeDir(home)

	result := map[string]interface{}{
		"ok":      false,
		"version": Version(),
	}

	raw, err := config.UnmarshalRawConfig([]byte(configYAML))
	if err == nil {
		raw.Tun.Enable = false
		raw.FindProcessMode = process.FindProcessOff
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

// Version 返回编译进库里的 mihomo 版本。
func Version() string {
	return constant.Version
}

// startTun 把 VpnService 的 fd 交给 mihomo 的 sing-tun 监听器。
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
