#!/usr/bin/env python3
"""把 mihomo 的 AAR 接进 `flutter create` 生成的 Android 工程。

为什么需要脚本而不是直接改文件：
  `android/app/build.gradle.kts` 是 CI 里由 `flutter create` 生成的，
  仓库里没有这个文件。所以只能在生成之后做一次确定性的补丁。

它做两件事：
  1. minSdk 改成 26（gomobile 的 -androidapi 26，AAR 的 minSdk 也是 26，
     不改会直接报 "uses-sdk:minSdkVersion 21 cannot be smaller than version 26"）；
  2. 追加 AAR 依赖（追加一个 dependencies {} 块是合法的，Gradle 允许重复调用）。
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

GRADLE = Path("android/app/build.gradle.kts")


def main() -> int:
    if not GRADLE.exists():
        print(f"[x] 找不到 {GRADLE}，flutter create 可能没执行成功", file=sys.stderr)
        return 1

    text = GRADLE.read_text(encoding="utf-8")
    original = text

    # Flutter 模板：minSdk = flutter.minSdkVersion
    text, n1 = re.subn(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 26", text)

    # 兼容老一点的 Groovy 模板：minSdkVersion flutter.minSdkVersion
    text, n2 = re.subn(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 26", text)

    if n1 + n2 == 0:
        print("[!] 没有找到 minSdk 声明，请检查生成的 build.gradle.kts")

    if "libs/core.aar" not in text:
        text = text.rstrip() + (
            "\n\n// 由 scripts/patch_android_gradle.py 注入：mihomo 内核\n"
            "dependencies {\n"
            '    implementation(files("libs/core.aar"))\n'
            "}\n"
        )

    if text != original:
        GRADLE.write_text(text, encoding="utf-8")

    print(f"[ok] minSdk 补丁: {n1 + n2} 处；AAR 依赖已就绪")
    print("----- 结果预览 -----")
    for line in GRADLE.read_text(encoding="utf-8").splitlines():
        if "minSdk" in line or "core.aar" in line or "dependencies" in line:
            print("   " + line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
