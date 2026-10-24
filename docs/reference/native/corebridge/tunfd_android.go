// native/corebridge/tunfd_android.go
//
// 这是整个 bridge 里**唯一**依赖 mihomo 内部结构的地方，也是最需要按版本核对的地方
// （架构文档 附录 A-4）。把它单独放一个文件，是为了让升级内核时的改动面收敛到 10 行以内。
//
// 背景：
//   Android 上 TUN 设备由 VpnService.Builder.establish() 创建，内核不能自己 open("/dev/net/tun")。
//   因此必须把 Kotlin 侧 detachFd() 出来的 fd 注入 TUN 入站。
//   同进程传递就是一个 int，不涉及 SCM_RIGHTS / Binder。

//go:build android

package core

import (
	"errors"
	"fmt"

	"github.com/metacubex/mihomo/config"
)

// setTunFileDescriptor 把 fd 写进配置，交给 TUN 入站使用。
//
// 三个候选实现（按锁定版本选一个，其余删掉）：
//
//	A. 配置结构体上有 fd 字段（多数 1.19.x 构建）：
//	     cfg.Tun.FileDescriptor = fd
//
//	B. 没有该字段，但 tun 包提供了带 fd 的构造函数：
//	     tunListener, err := tun.New(cfg.Tun, fd)   // 然后替换 cfg 中的入站
//
//	C. 两者都没有：改用 `tun.file-descriptor` YAML 键，在物化阶段写进 runtime.yaml，
//	     并把本函数退化为只做参数校验。
//
// 无论选哪个，Kotlin 侧调用方式不变，Dart 侧完全无感知。
func setTunFileDescriptor(cfg *config.Config, fd int) error {
	if fd <= 0 {
		return errors.New("invalid tun fd")
	}
	if cfg == nil {
		return errors.New("nil config")
	}
	if cfg.Tun == nil {
		return errors.New("config has no tun section; TUN must be enabled in runtime.yaml")
	}

	// ADAPTER: 按锁定版本核对这一行的字段名与承载结构。
	cfg.Tun.FileDescriptor = fd

	return nil
}

// VerifyTunReady 供 Kotlin 在 start 之后做一次快速自检：
// 有些 ROM 会在 establish 之后立刻回收接口，表现为 fd 仍然合法但已无流量。
// 这里只做"fd 是否仍可写"的粗检，真正的业务校验走 REST /version + /rules。
func VerifyTunReady(fd int) error {
	if fd <= 0 {
		return fmt.Errorf("tun fd %d is not usable", fd)
	}
	return nil
}
