module github.com/tide/client-core

// tool 指令要求 go >= 1.24
go 1.24.0

require (
	github.com/metacubex/mihomo v1.19.33
	// 新版 gomobile 要求 x/mobile 必须在当前模块的依赖图里。
	// 版本对应 golang/mobile master 上的真实提交 197770444867…（2026-10-11T03:45:28Z）。
	golang.org/x/mobile v0.0.0-20261011034528-197770444867
)

// gomobile bind 会检查这条 tool 指令，缺失时会直接拒绝执行。
tool golang.org/x/mobile/cmd/gobind

// 用 CI 里克隆并打过补丁的 mihomo 源码（跳过读取 /data/system/packages.xml）。
// 目录由 workflow 的“克隆 mihomo 源码并打补丁”步骤生成：native/mihomo。
replace github.com/metacubex/mihomo => ../mihomo

// mihomo 自己的 go.mod 里有一条 replace（protobuf 换成了 metacubex 的 fork）。
// 依赖模块里的 replace 会被 Go 忽略，所以这里必须原样再写一遍。
replace google.golang.org/protobuf => github.com/metacubex/protobuf-go v0.0.0-20260306035419-7ceee0674686
