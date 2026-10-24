# 双端兼容改造说明（Android / Windows）

这份文档回答两个问题：**之前那套代码里哪些是 Android 专属的**、**现在用什么办法让同一套 Dart 代码在两端都编得过**。

---

## 1. 之前代码里"只有 Android 能用"的部分

| 原路径 | 为什么是 Android 专属 | 现在的处理 |
|---|---|---|
| `android/app/src/main/kotlin/com/tide/tunnel/TunnelService.kt` | `VpnService`、前台服务、`Notification`、`ConnectivityManager`、`onRevoke` —— 全是 Android framework API，Windows 上连编译都过不了 | 移到 [docs/reference/android/tunnel/](reference/android/tunnel/)，**不参与编译** |
| `android/app/src/main/kotlin/com/tide/tunnel/TunnelState.kt` | 与 VpnService 生命周期强绑定（`onRevoke`、前台服务状态），状态机里含 Android 语义 | 同上 |
| `android/app/src/main/kotlin/com/tide/tunnel/TunnelSupport.kt` | `SharedPreferences` / `EncryptedSharedPreferences` / Keystore | 同上 |
| `android/app/src/main/AndroidManifest.xml`（含 `BIND_VPN_SERVICE`、`specialUse` 前台服务） | Android 清单文件 | 保留一份参考：[AndroidManifest.reference.xml](reference/android/AndroidManifest.reference.xml)；主清单已去掉 service |
| `native/corebridge/*.go` | 通过 `gomobile bind` 只能产出 Android AAR / iOS xcframework，需要 NDK；桌面端用不到 | 移到 [docs/reference/native/](reference/native/) |
| `packages/clash_schema/lib/models.dart` | 平台无关，但依赖较重、第一阶段用不上（页面用的是简化模型） | 移到 [docs/reference/packages/](reference/packages/)，并入后续 `lib/core/` |
| `app/lib/design/tokens.dart` | Flutter 通用，但旧版里混了组件与高风险 API | 重写为 [lib/design/tokens.dart](../lib/design/tokens.dart) |

### 为什么必须"移出去"，而不是留着注释掉

Gradle 会把 `android/app/src/main/kotlin/` 下的**所有** `.kt` 文件都编译。旧 `TunnelService.kt` 里有：

```kotlin
import com.tide.core.Core          // 来自 gomobile 产物 core.aar
...
Core.start(home, configPath, pendingFd)
```

而第一阶段**不打包** `core.aar`。只要这个文件还在源码目录里，`flutter build apk` 就会报 `Unresolved reference: Core`，整个构建直接失败。

所以：**编译目录里只保留当前阶段真的能编过的代码**，其余进 `docs/reference/` 当资料。这是"降级"能一次成功的关键。

---

## 2. 平台能力怎么隔离：一个接口 + 三个实现 + 一个工厂

```
页面（lib/features/**）
        │  只调用 controller.toggleConnection()
        ▼
AppController（lib/core/app_controller.dart）
        │  只依赖 TunnelPlatform 抽象
        ▼
TunnelPlatform（lib/core/tunnel/tunnel_platform.dart）   ← 唯一的平台无关契约
        ├── MethodChannelTunnelPlatform   （Android，走真实原生通道）
        ├── SimulatedTunnelPlatform       （Windows / 降级，本地模拟）
        └── （未来）WindowsMihomoPlatform  （Dart 起子进程 + HTTP）
                    ▲
        tunnel_factory.dart 里只有这一处 if：
            defaultTargetPlatform == TargetPlatform.android ? A : B
```

**规则（写进 Code Review）**：

1. `lib/features/` 里**禁止** import `package:flutter/services.dart`，禁止出现 `defaultTargetPlatform`。
2. 平台差异只允许出现在 `tunnel_factory.dart` 一个文件里。
3. 原生实现缺失时必须**降级**，不能让 App 崩：`MethodChannelTunnelPlatform` 把 `MissingPluginException` 全部捕获成 `false` / `StateError`，`AppController.init()` 收到后自动换成模拟实现。
4. 两端传给 Dart 的状态使用**同一个 Map 协议**，这样 Android 换成真实内核、Windows 换成子进程时，Dart 都不用改。

### 通道协议（Android 实现，Windows 未来照抄）

| 通道 | 名称 | 方法/事件 | 返回 |
|---|---|---|---|
| MethodChannel | `tide/tunnel` | `isAvailable()` | `bool`：原生实现是否存在 |
| | | `getState()` | `Map`：当前状态（首帧用，不等事件） |
| | | `connect({profileId})` | `Map`：调用后的即时状态 |
| | | `disconnect()` | `Map` |
| EventChannel | `tide/tunnel/events` | 状态推送 | `Map` |

`Map` 字段（`TunnelState.fromMap` 解析）：

| key | 类型 | 说明 |
|---|---|---|
| `phase` | String | `idle` / `connecting` / `connected` / `disconnecting` / `failed` |
| `profileId` | String? | 当前配置 id |
| `message` | String? | 给用户看的一句话 |
| `nativeAvailable` | bool | 是否接入了真实内核（false = 演示模式） |
| `down` / `up` | int | 每秒字节数 |
| `connectionCount` | int | 活跃连接数 |

**新增一个平台要改哪里？** 只改两处：加一个 `implements TunnelPlatform` 的文件；在 `tunnel_factory.dart` 加一个分支。页面零改动。

---

## 3. 目录结构：改造前 vs 改造后

### 改造前（Android 单端，且假设已接内核）

```
clash-meta-client/
├── app/lib/design/tokens.dart
├── packages/clash_schema/lib/models.dart
├── native/corebridge/*.go
├── android/app/src/main/
│   ├── AndroidManifest.xml            (含 VPN service)
│   └── kotlin/com/tide/tunnel/*.kt   (VpnService + 状态机)
└── ARCHITECTURE.md
```

### 改造后（双端可编译）

```
clash-meta-client/
├── pubspec.yaml                  ← 项目根标志；没有它 flutter 命令全报错
├── lib/                          ← 100% 双端共用
│   ├── main.dart / app.dart
│   ├── design/tokens.dart
│   ├── core/{app_controller,app_scope,profile}.dart
│   ├── core/tunnel/*.dart        ← 隔离层
│   ├── features/{connect,profiles,logs,settings}/
│   └── widgets/common.dart
├── android/app/src/main/
│   ├── AndroidManifest.xml        ← 自定义，flutter create 不会覆盖
│   └── kotlin/com/tide/tide/
│       ├── MainActivity.kt
│       └── TunnelChannel.kt       ← 模拟状态机，证明通道可用
├── test/                          ← 纯逻辑测试，不依赖设备
├── docs/reference/                ← 旧代码，仅参考，不编译
├── .github/workflows/build.yml
└── README.md
```

`android/` 里**故意只放自定义文件**。`gradle/`、`gradle wrapper`、`res/`、`build.gradle.kts` 这些由 CI 里的
`flutter create --platforms=android ...` 按当时的 Flutter 版本生成 —— 这样不会出现"仓库里的 Gradle 版本和 Runner 上的 Flutter 不匹配"的经典故障。

---

## 4. `pubspec.yaml` 该怎么写、为什么这么写

当前版本：

```yaml
name: tide            # 只能是合法 Dart 包名（小写、下划线）
environment:
  sdk: ">=3.4.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
```

**刻意只留最少依赖**，理由：

1. 依赖越少，`flutter pub get` 越快、越不容易出现版本冲突；
2. 第一阶段的功能（页面、状态机、通道）用 SDK 自带能力就够；
3. 一旦引入 `build_runner` / `freezed` / `riverpod_generator`，CI 就要多跑一步代码生成，初学者排错成本翻倍。

第二阶段真正需要时再加（`flutter pub add` 会自动写进 pubspec 并锁定版本）：

| 依赖 | 什么时候需要 |
|---|---|
| `http` 或 `dio` | 调 mihomo 的 REST API、拉订阅 |
| `web_socket_channel` | 订阅 `/connections`、`/logs`、`/traffic` 的实时流 |
| `path_provider` | 拿 App 私有目录存配置与规则集缓存 |
| `file_picker` | 从系统文件选择器导入 `.yaml` |
| `sqlite3` / `drift` | 连接日志落库、历史查询 |

> 不要一开始就上 Riverpod：本项目的页面状态很浅，一个 `ChangeNotifier` + `InheritedNotifier`
> 已经够用，而且能让新手一眼看懂数据怎么流。等页面多起来再迁移，成本很低。

---

## 5. Windows 端现在是什么、以后怎么接

### 现在

- `windows/` 目录在构建时由 `flutter create --platforms=windows` 生成；
- Dart 侧走 `SimulatedTunnelPlatform`，连接按钮、状态点、流量数字都是本地模拟；
- **没有一行 C++**。

### 以后接真实能力，两条路

| 方案 | 做法 | 评价 |
|---|---|---|
| **A. 纯 Dart（推荐）** | 把 `mihomo.exe` 作为 asset 打包，首次启动解压到 `%APPDATA%\tide\core`，用 `Process.start(exe, ['-d', workDir, '-f', configPath])` 拉起，再用 `http` 调 `127.0.0.1:9090` | 零 C++、零 MethodChannel，Dart 天生能起进程；调试简单 |
| B. C++ runner 注册通道 | 改 `windows/runner/`，用 `MethodChannel` 暴露原生能力 | 需要写 C++ 且要维护生成的 runner，首版不划算 |

Windows 上要注意：

- **TUN 模式需要管理员权限**（wintun 驱动）。建议先做"系统代理模式"：mihomo 开 `mixed-port`，再把系统代理指过去，免提权。
- 进程退出/崩溃要监听 `exitCode`，否则会出现"UI 显示已连接、实际没有代理"。
- 升级内核时 exe 文件会被占用（Windows 不允许覆盖运行中的 exe），要先 `kill` 并等进程真正退出。

---

## 6. 这套做法的代价（提前说清）

| 代价 | 说明 | 缓解 |
|---|---|---|
| CI 每次多 20–40 秒 | 生成平台目录 | 可接受；比版本错配便宜 |
| 仓库里看不到完整 `android/` 结构 | 新手会疑惑"为什么没有 build.gradle" | README 已解释 |
| 要改 Gradle（加 AAR / 改 minSdk）时不能直接改文件 | 文件是生成出来的 | 见 [PHASE2_CORE.md](PHASE2_CORE.md) 里的 Python patch 片段 |
| Flutter 大版本升级可能改变默认值 | 例如默认 minSdk、compileSdk | 在 workflow 里锁 `flutter-version` |

---

## 7. 风险清单

1. **Flutter 版本漂移**：`channel: stable` 会一直取最新版。如果哪天构建突然失败，先把 workflow 里的 `flutter-version` 锁到上一个能过的版本。
2. **`.github` 没上传**：最最常见的失败，症状是 Actions 页面空的。README 第 2 节有自检步骤。
3. **路径多套一层**：如果仓库根目录是 `clash-meta-client/` 而不是文件本身，`pubspec.yaml` 就找不到，`flutter create` 会把它当新项目初始化，最后编译出一个空壳。务必让 `pubspec.yaml` 在仓库最外层。
4. **Windows 打包漏文件**：只复制 exe 必然打不开，workflow 里已经整目录压缩。
5. **APK 用调试签名**：只能自用，不能上架。
