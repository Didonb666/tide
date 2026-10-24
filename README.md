# Tide · 双端可编译起步包

一句话：**这是一个能在 GitHub 云端自动打出 Android APK 和 Windows EXE 的 Flutter 项目**，四个页面、状态机、原生通道都已打通；但它暂时**不代理流量**（原因见下面「先说清楚」）。

---

## ⚠️ 先说清楚：这一版能做什么、不能做什么

| 能 | 不能 |
|---|---|
| 在 GitHub 上一键构建出 `.apk` 和 `.exe` | 真正接管/转发手机或电脑的网络流量 |
| App 装到手机、电脑上正常打开 | 导入 Clash.Meta 配置后自动分流 |
| 四个页面（连接 / 配置 / 日志 / 设置）可点、带动效 | 启动 mihomo 内核 |
| Android 上走**真实的 Kotlin 通道**（MethodChannel / EventChannel） | 订阅自动更新、规则集下载 |

**为什么先做"壳子"？** 因为把 mihomo 内核编进 Android 需要 Go + Android NDK + gomobile，构建时间会从 8 分钟涨到 25 分钟以上，失败率也高。对第一次用 GitHub Actions 的人来说，先拿到两个能装能开的安装包，再逐步加内核，成功率最高。第二阶段步骤写在 [docs/PHASE2_CORE.md](docs/PHASE2_CORE.md)。

---

## 0. 你会拿到哪两个文件

构建成功后，在 GitHub 的 Actions 页面能下载到两个 **zip**：

| 下载的 artifact | 解压后 | 用途 |
|---|---|---|
| `tide-android-apk` | `app-release.apk` | 传到安卓手机安装 |
| `tide-windows-x64` | `tide.exe` + 一堆 `.dll` + `data` 文件夹 | 双击 `tide.exe` 运行 |

> Windows 端**必须解压整个 zip 再双击 exe**。只把 exe 拖出来是打不开的（它依赖同目录的动态库和 `data` 文件夹）。

---

## 1. 注册 GitHub 并新建仓库（5 步）

1. 打开 <https://github.com/signup>，填邮箱、密码、用户名（用户名只能用英文/数字/连字符，例如 `xiaoming-2026`）。
2. 去邮箱点验证链接，完成注册。
3. 登录后，点右上角 **`+`** → **New repository**。
4. 填写：
   - **Repository name**：`tide`（只能用英文数字和 `-`、`_`）
   - **Description**：随便写，可留空
   - 选 **Public**（公开仓库的 Actions 分钟数免费且不限；私有仓库每月只有 2000 分钟）
   - **不要**勾 "Add a README file"
5. 点绿色 **Create repository**。

创建完页面会显示仓库地址，形如：

```
https://github.com/你的用户名/tide
```

---

## 2. 把代码上传到仓库

### 方案 A：网页拖拽（最快，推荐先试）

1. 在电脑上把我给你的文件夹**解压**，进入文件夹，确认你**直接**能看到这些东西：

   ```
   .github/          ← 必须有！没有它就没有自动构建
   android/
   lib/
   test/
   docs/
   pubspec.yaml      ← 必须有！
   analysis_options.yaml
   .gitignore
   README.md
   ARCHITECTURE.md
   ```

   > 注意：是这些文件/文件夹**本身**在根目录，而不是外面再套一层 `clash-meta-client/`。
   > 如果多套了一层，GitHub 就找不到 `.github/workflows/build.yml`，什么都不会发生。

2. 打开你的仓库页面，点 **Add file** → **Upload files**。
3. 用文件管理器选中上面这些内容（`.github`、`lib`、`android` … `pubspec.yaml`），**整个拖进浏览器页面**。
   - 拖文件夹会自动带上里面的所有子文件，`.github` 也可以这样拖。
   - **不要**把 `.zip` 压缩包直接拖进去 —— GitHub 不会自动解压。
4. 页面下方 **Commit changes** → 再点一次 **Commit changes**。

### 方案 B：GitHub Desktop（文件多时更稳）

1. 下载安装 <https://desktop.github.com/>，用同一账号登录。
2. **File → Clone repository** → 选你的 `tide` → 选一个本地空文件夹 → Clone。
3. 把项目文件全部复制进那个本地文件夹（同样注意：`pubspec.yaml` 要在最外层）。
4. 在 GitHub Desktop 左下角写一句 Summary（例如 `init`）→ **Commit to main** → 右上角 **Push origin**。

### 上传完自检

- 仓库首页应该**直接**看到 `pubspec.yaml`、`lib`、`.github`。
- 顶部应该出现 **Actions** 标签。
- 点 Actions，左侧应看到 **Build APK & EXE**。

如果 Actions 标签里空空如也，99% 是 `.github` 没上传成功，回到方案 A 重传一次。

---

## 3. 触发构建

上传完成后**通常会自动开始**（因为推送会触发）。

想手动触发：

1. 点仓库顶部 **Actions**。
2. 左侧点 **Build APK & EXE**。
3. 右侧点 **Run workflow** → 绿色 **Run workflow** 按钮。
4. 刷新页面，会出现一条正在跑的记录（黄色圆点）。

构建过程：

| Job | 环境 | 大约耗时 |
|---|---|---|
| 构建 Android APK | Ubuntu | 5–10 分钟（首次会下载依赖，慢一些） |
| 构建 Windows EXE | Windows | 6–12 分钟 |

两个 Job 并行跑，互不影响。**一个失败不影响另一个**，可以只下成功的那个。

---

## 4. 下载安装包

1. 等那次运行变成**绿色 ✓**。
2. 点进这次运行，往下滚到页面**最底部**，找到 **Artifacts** 区域。
3. 点 `tide-android-apk` 下载 → 得到一个 zip → 解压出 **`app-release.apk`**。
4. 点 `tide-windows-x64` 下载 → 得到一个 zip → **整个解压**。

> Artifacts 默认保留 **30 天**，过期就没了，重新跑一次构建即可。

---

## 5. 安装 / 运行

### Android

1. 把 `app-release.apk` 传到手机（微信文件传输助手 / 数据线 / 网盘都行）。
2. 在手机上点开这个 apk。
3. 系统提示"出于安全考虑，禁止安装未知来源应用" → 点**设置** → 允许该来源 → 返回继续安装。
4. 打开 App。第一次启动是浅色主题，可到「设置」里切深色。

> 这个 APK 用调试证书签名，自己用没问题，但**不能上架应用商店**。

### Windows

1. 把 `tide-windows-x64.zip` **完整解压**到一个文件夹（不要只拖 exe 出来）。
2. 双击 **`tide.exe`**。
3. 如果弹出"Windows 已保护你的电脑"：点**更多信息** → **仍要运行**（因为 exe 没有代码签名证书）。

---

## 6. 常见问题

| 现象 | 原因 / 解决 |
|---|---|
| Actions 标签里没有 `Build APK & EXE` | `.github/workflows/build.yml` 没上传，或上传后多套了一层文件夹。检查仓库首页能否直接看到 `.github` |
| 构建红叉，`flutter create` 这一步失败 | 仓库根目录没有 `pubspec.yaml`。把文件移到最外层再提交 |
| 构建红叉，其他步骤失败 | 点红色那一步，把**最后 30 行日志**复制出来看。90% 是代码/配置问题，日志会直接说哪一行 |
| Artifacts 区域是空的 | 构建没成功；或者运行太早（还没跑完）；或者已过 30 天 |
| 下载按钮点不动 | 需要登录 GitHub；未登录只能看不能下 |
| APK 装不上 | 没允许"未知来源"；或手机里已有同包名 App，先卸载旧的 |
| Windows 双击没反应/报缺 dll | 只复制了 exe。必须解压整个 zip，保持 `tide.exe`、`*.dll`、`data/` 在一起 |
| 打开后点"连接"显示演示模式 | 正常。这一版没有内核，见 [docs/PHASE2_CORE.md](docs/PHASE2_CORE.md) |

---

## 7. 本地运行（可选，不改代码也能跳过）

需要三样东西：

1. **Flutter SDK**：<https://docs.flutter.dev/get-started/install>（装完在终端执行 `flutter doctor`，全绿最好）
2. **Android**：Android Studio（自带 SDK 与模拟器）
3. **Windows**：Visual Studio 2022，安装时勾选"使用 C++ 的桌面开发"

然后在本项目根目录执行：

```bash
# 第一次必须先补齐平台目录（gradle、CMake、runner 等模板文件）
flutter create --platforms=android,windows --org com.tide --project-name tide .

flutter pub get
flutter run -d windows          # 或 flutter devices 看设备名
flutter run -d emulator-5554    # Android 模拟器
```

> 为什么要 `flutter create`？因为仓库里只保留了**我们自定义**的原生文件（`MainActivity.kt`、`AndroidManifest.xml` 等），
> 而 `gradle`、`gradle wrapper`、`CMakeLists.txt`、`windows/runner` 这些模板文件由 Flutter 按**你本机的 SDK 版本**生成，
> 这样就不会出现"别人给的 Gradle 版本和我装的 Flutter 不匹配"的经典问题。CI 里也是同一条命令。

---

## 8. 目录地图

```
tide/
├── .github/workflows/build.yml   ← 一键打包脚本（两个 Job）
├── pubspec.yaml                  ← Flutter 项目配置（依赖、版本号）
├── lib/                          ← 所有 Dart 代码（Android/Windows 共用）
│   ├── main.dart                 ← 入口
│   ├── app.dart                  ← MaterialApp + 四栏导航
│   ├── design/tokens.dart        ← 颜色/圆角/字级/动效 Token
│   ├── core/
│   │   ├── app_controller.dart   ← 全局状态（不用 Riverpod，少装依赖）
│   │   ├── profile.dart          ← 配置/策略组/规则的数据模型
│   │   └── tunnel/               ← ★ 双端隔离层
│   │       ├── tunnel_platform.dart      ← 抽象接口（唯一的"平台无关"契约）
│   │       ├── method_channel_tunnel.dart← Android 实现
│   │       ├── simulated_tunnel.dart     ← 桌面/降级实现
│   │       └── tunnel_factory.dart       ← 按平台选择，只在这里 if
│   ├── features/                 ← 四个页面
│   └── widgets/common.dart       ← 复用组件（状态点/分隔线/列表行）
├── android/                      ← 只有自定义文件；其余由 flutter create 补齐
│   └── app/src/main/
│       ├── AndroidManifest.xml
│       └── kotlin/com/tide/tide/{MainActivity.kt, TunnelChannel.kt}
├── test/                         ← 两个纯逻辑测试
├── docs/
│   ├── PLATFORM_NOTES.md         ← 哪些代码是 Android 专属、怎么隔离的
│   ├── PHASE2_CORE.md            ← 接入 mihomo 内核的完整步骤
│   └── reference/                ← 之前那套 VpnService / Go bridge 源码（仅参考，不参与编译）
└── ARCHITECTURE.md               ← 完整架构方案（较深，可以先不看）
```

**关键点**：`lib/` 里没有一处 `Platform.isAndroid` 的判断散落在页面中；平台差异全部收敛在
`lib/core/tunnel/tunnel_factory.dart` 一个文件里。

---

## 9. 下一步

1. 先确认两个包都能下载、能打开、四个页面都能点。
2. 想改 App 名字：改 `android/app/src/main/AndroidManifest.xml` 里的 `android:label`，以及 `pubspec.yaml` 的 `description`。
3. 想让 Android 真正能代理：按 [docs/PHASE2_CORE.md](docs/PHASE2_CORE.md) 接入 mihomo。
4. 想接 Windows 真实代理：同文档最后一节，Windows 端**不需要写 C++**，用 Dart 启动 `mihomo.exe` 子进程即可。
