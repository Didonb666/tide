# 第二阶段：接入 mihomo 内核

第一阶段（当前）是可编译的双端外壳；这份文档给它装上真正的心脏。
**不要一次全做**，按下面 0 → 5 的顺序，每步都有明确的验收点。

---

## 0. 先选路线

| 平台 | 路线 | 需要什么 | 难度 |
|---|---|---|---|
| Android | mihomo 编成 `core.aar`（gomobile），在 VPN 服务进程内运行 | Go 1.23+、Android NDK r27+、gomobile | 中 |
| Windows | **不写 C++**：把 `mihomo.exe` 当子进程拉起，Dart 用 HTTP 控制 | 只要一个 mihomo release 压缩包 | 低 |

Android 之所以必须编成库：`VpnService` 建好的 TUN 是一个 fd，跨进程传 fd 很麻烦；同进程直接传一个 `int` 最省事。
Windows 之所以不用编库：桌面端允许 `CreateProcess`，Dart 的 `dart:io` 直接能起子进程，控制面走本机 HTTP 即可。

---

## 1. Android：编出 core.aar

在 `docs/reference/native/corebridge/` 那套 Go 代码基础上（把它挪回仓库的 `native/corebridge/`）：

```bash
# 一次性环境
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init

cd native/corebridge
go mod init github.com/<你的名字>/tide-corebridge
go get github.com/metacubex/mihomo@v1.19.5   # 锁一个具体 tag
go mod tidy

gomobile bind \
  -target=android/arm64,android/arm \
  -androidapi 26 \
  -javapkg com.tide.core \
  -tags with_gvisor \
  -ldflags "-s -w -extldflags=-Wl,-z,max-page-size=16384" \
  -trimpath \
  -o ../../android/app/libs/core.aar .
```

验收：`core.aar` 生成成功，解压后能看到 `jni/arm64-v8a/libgojni.so`。

> 16KB page size 是 Android 15+ 设备与 Google Play 的硬要求，`-max-page-size=16384` 不能省。

---

## 2. Android：让 Gradle 认识这个 AAR

`android/app/build.gradle.kts` 是 `flutter create` 生成的，**不在仓库里**，所以要用 CI 步骤"打补丁"。
在 workflow 的 "生成 Android 平台目录" 之后、"编译 APK" 之前插入：

```yaml
      - name: 注入 mihomo AAR 依赖
        run: |
          python3 - <<'PY'
          from pathlib import Path
          p = Path('android/app/build.gradle.kts')
          s = p.read_text(encoding='utf-8')
          s = s.replace(
              'dependencies {',
              'dependencies {\n    implementation(files("libs/core.aar"))',
              1,
          )
          p.write_text(s, encoding='utf-8')
          print('patched build.gradle.kts')
          PY
```

同时确保 AAR 在仓库里：`android/app/libs/core.aar`（约 30–60 MB，建议用 Git LFS，或让 CI 先构建 AAR 再打包 APK）。

---

## 3. Android：恢复 VpnService

把 `docs/reference/android/tunnel/` 下三个文件复制回 `android/app/src/main/kotlin/com/tide/tunnel/`，然后：

1. 清单里加回 service 与权限（照抄 `docs/reference/android/AndroidManifest.reference.xml`）：
   `FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_SPECIAL_USE`、`POST_NOTIFICATIONS`、
   `<service ... android:permission="android.permission.BIND_VPN_SERVICE" android:foregroundServiceType="specialUse">`。
2. `MainActivity` 不再直接和 Dart 通信，而是把 `TunnelChannel` 的 `connect` 转成
   `startForegroundService(Intent(this, TunnelService::class.java).putExtra(...))`。
3. `TunnelService` 负责：`VpnService.Builder.establish()` → `detachFd()` → `Core.start(home, configPath, fd)`。
4. 状态通过 `TunnelStateBus` 回传，`TunnelChannel` 把它转成 EventChannel 的 Map。

**注意**：`detachFd()` 之后绝不能再 `close()` 那个 `ParcelFileDescriptor`，否则 fd 号会被复用，表现为"连上了但所有流量黑洞"。

验收：装上 APK → 点连接 → 系统弹 VPN 授权 → 通知栏出现"已连接"→ `adb logcat | grep TideTunnel` 能看到 fd 和内核启动日志。

---

## 4. Dart 侧：一行不用改

因为通道协议没变（`phase` / `message` / `nativeAvailable` …），只要把 Kotlin 返回的
`nativeAvailable` 改成 `true`，UI 自动不再显示"演示模式"。

需要补的是**数据**：把 `lib/core/profile.dart` 里的 mock 换成从内核 API 读：

| UI | 接口 | 说明 |
|---|---|---|
| 策略组 | `GET /proxies` | 过滤 `Selector / URLTest / Fallback / LoadBalance`，`now` 是当前选中 |
| 规则列表 | `GET /rules` | 按 `index` 原样展示，**不要排序**（首条命中即停） |
| 规则集 | `GET /providers/rules` | `ruleCount`、`updatedAt` |
| 连接日志 | `GET /connections`（或 WS，`?interval=2000`） | 每条自带 `rule` / `rulePayload` / `chains` |
| 切节点 | `PUT /proxies/{组名}` body `{"name":"节点"}` | |
| 热重载 | `PUT /configs?force=true` body `{"path":"<workdir 内的绝对路径>"}` | |

请求头带 `Authorization: Bearer <secret>`；`secret` 与随机端口在物化配置时注入，
`external-controller` 只绑 `127.0.0.1`。

---

## 5. Windows：纯 Dart 接内核

1. 从 mihomo release 下载 `mihomo-windows-amd64.zip`，把 `mihomo.exe` 放到 `assets/core/mihomo.exe`，
   并在 `pubspec.yaml` 声明：

   ```yaml
   flutter:
     assets:
       - assets/core/mihomo.exe
   ```

2. 首次启动时把它复制到可写目录（asset 是只读的，不能直接执行）：

   ```dart
   final dir = await getApplicationSupportDirectory();   // path_provider
   final exe = File('${dir.path}/core/mihomo.exe');
   if (!await exe.exists()) {
     final data = await rootBundle.load('assets/core/mihomo.exe');
     await exe.create(recursive: true);
     await exe.writeAsBytes(data.buffer.asUint8List());
   }
   ```

3. 拉起进程：

   ```dart
   final process = await Process.start(
     exe.path,
     ['-d', '${dir.path}/core', '-f', '${dir.path}/core/runtime.yaml'],
   );
   process.exitCode.then((code) => /* 上报"内核已退出" */);
   ```

4. 轮询 `http://127.0.0.1:<port>/version` 直到 200，再切到 `connected`。

**先做系统代理模式**：`runtime.yaml` 里给 `mixed-port: 7890`，然后调 Windows 的系统代理设置指向
`127.0.0.1:7890`。TUN 模式要 wintun 驱动 + 管理员权限，放最后做。

验收：Windows 上点连接 → `mihomo.exe` 出现在任务管理器 → 浏览器能通过代理访问网络。

---

## 6. 导入 / 校验链路（接内核后才真正开始）

第一阶段的"导入"只是保存原文 + 粗略数规则行数。接内核后要补齐：

1. **静态 lint**（Dart）：`MATCH` 必须在最后一行且只有一条、规则 type 合法、策略组引用的节点存在、
   `rule-providers` 的 `behavior × format` 兼容。
2. **内核权威校验**：让内核自己 parse 一遍（Android 走 Go bridge 的 `Validate()`，Windows 走 `mihomo -t -f config.yaml`）。
   这是唯一可信的裁决。
3. **物化**：把用户 YAML 补上 `external-controller`、随机 `secret`、`allow-lan: false`、
   provider 的本地 `path`，写到 `<workdir>/runtime.yaml`（**不要改原文**）。
4. **下发 + 核验**：`PUT /configs?force=true` → `GET /rules` 比对条数 → 对不上就回滚到上一份。

---

## 7. 法律与合规（别跳过）

- **mihomo 是 GPL-3.0**。用 gomobile 静态链接进 App，等于整个 App 要以 GPL-3.0 分发：
  必须公开源码、保留许可证、允许他人再分发。想闭源上架，请先找律师评估，别赌。
- Windows 端以独立进程分发 mihomo.exe，边界更清晰，但仍有争议，同样建议 GPL 开源。
- 只做"网络工具"，不要内置任何节点、订阅或翻墙引导；这类 App 在应用商店的上架政策风险由你自己承担。

---

## 8. 建议顺序与验收表

| 步骤 | 验收 | 预计 |
|---|---|---|
| 1. AAR 能编出来 | `core.aar` 存在且 APK 体积 < 80MB | 半天 |
| 2. TUN 能建起来 | 通知栏出现 VPN 图标，logcat 有 fd | 半天 |
| 3. 内核能起来 | `GET /version` 返回 200 | 1 天 |
| 4. 规则能展示 | `GET /rules` 条数与订阅一致 | 1 天 |
| 5. 真实流量走通 | 打开网页，日志里能看到命中的规则 | 1 天 |
| 6. Windows 子进程 | 电脑上能通过代理上网 | 1 天 |

更完整的架构细节（配置生命周期失败点、规则集更新、Android 保活边界、动效规范）见 [ARCHITECTURE.md](../ARCHITECTURE.md)。
