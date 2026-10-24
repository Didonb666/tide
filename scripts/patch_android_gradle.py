#!/usr/bin/env python3
"""给 flutter create 生成的 Android 工程打补丁：

1. 包名统一成 com.fstool.app（namespace + applicationId）；
2. minSdk 提到 26（gomobile 的 AAR 要求）；
3. 引入 mihomo 的 core.aar。
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

    # 1) 包名
    text = text.replace("com.tide.tide", "com.fstool.app")
    text = re.sub(
        r'namespace\s*=\s*"[^"]+"',
        'namespace = "com.fstool.app"',
        text,
        count=1,
    )
    text = re.sub(
        r'applicationId\s*=\s*"[^"]+"',
        'applicationId = "com.fstool.app"',
        text,
        count=1,
    )

    # 2) minSdk
    text, n1 = re.subn(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 26", text)
    text, n2 = re.subn(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 26", text)

    # 3) AAR
    if "libs/core.aar" not in text:
        text = text.rstrip() + (
            "\n\n// 由 scripts/patch_android_gradle.py 注入：mihomo 内核\n"
            "dependencies {\n"
            '    implementation(files("libs/core.aar"))\n'
            "}\n"
        )

    if text != original:
        GRADLE.write_text(text, encoding="utf-8")

    print(f"[ok] 包名 -> com.fstool.app；minSdk 补丁 {n1 + n2} 处；AAR 依赖已就绪")
    for line in GRADLE.read_text(encoding="utf-8").splitlines():
        if "namespace" in line or "applicationId" in line or "minSdk" in line or "core.aar" in line:
            print("   " + line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
