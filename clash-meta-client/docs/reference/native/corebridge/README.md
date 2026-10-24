# native/corebridge

把**未修改的 mihomo** 编成 gomobile 库，供 Android 在 VPN 进程内直接调用。

## 为什么不是一个 fork

我们要的是"Clash.Meta 规则一等公民"，不是"能跑就行"。fork 会让每次内核升级都变成合并冲突，
而我们的差异化其实全在配置物化、校验、UI 和生命周期上——这些都不需要改内核。
本目录只做三件事：调用内核 parser、启停内核、注入 TUN fd。

## go.mod

```go
module github.com/<you>/tide-corebridge

go 1.23

require github.com/metacubex/mihomo v1.19.x // 锁死具体 tag，升级走 PR + 回归

// 如果 mihomo 依赖的某些包在新版本里改了行为，用 replace 固定，而不是升级全部依赖
```

## 构建

```bash
./build.sh
# 产物：android/app/libs/core.aar
# Java 类：com.tide.core.Core
```

Kotlin 侧调用：

```kotlin
Core.start(home, configPath, tunFd) // 返回 null / 抛异常
Core.stop()
Core.validate(home, configPath)     // 返回 JSON 字符串
Core.version()
```

## 升级内核的 checklist

1. 改 `go.mod` 的 mihomo 版本，`go mod tidy`。
2. `./build.sh` 编过。
3. 跑 `testdata/` 里 30 份 YAML 回归（含 flow 风格、MATCH 位置错误、provider 引用缺失等）。
4. 真机跑：连接 → 切节点 → 热重载配置 → 更新 provider → 断开，观察 fd 与内存。
5. 重点核对 `tunfd_android.go` 的 ADAPTER 那一行（fd 注入方式随版本可能变化）。
6. 记录 `GET /version` 输出到 `docs/verified-against.md`。

## 体积

- `with_gvisor` 会显著增大 so；如果只用 `system`/`mips` 栈，去掉该 tag 可省几 MB。
- AAR 内含两个 ABI 时体积接近翻倍；发布走 App Bundle 的 ABI split，不要发 universal APK。
- geo 数据不要打进 so，放 assets 首次启动解压到 `<data>/core/geo/`。
