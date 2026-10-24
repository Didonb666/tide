#!/usr/bin/env bash
# native/corebridge/build.sh
#
# 把 mihomo 编成 Android 可用的 AAR。CI 与本地都用这个脚本，避免"我这能编"。
#
# 前置：
#   Go >= 1.23（mihomo 与 16KB page size 都需要较新的工具链）
#   gomobile + gobind：go install golang.org/x/mobile/cmd/gomobile@latest && gomobile init
#   Android NDK（r27+，16KB page size 支持更完整）
#   ANDROID_HOME / ANDROID_NDK_HOME 已设置

set -euo pipefail

cd "$(dirname "$0")"

OUT="${OUT:-../../android/app/libs/core.aar}"
TAGS="${TAGS:-with_gvisor}"          # TUN 栈需要；只保留用得到的 tag 以控制体积
ABIS="${ABIS:-android/arm64,android/arm}"

# 16KB page size：Android 15+ 设备与 Play 的硬要求。
# 只加链接参数不够，还需要 NDK r27+ 与 Go 1.23+ 的配合，CI 必须在 16KB 模拟器上实测。
LDFLAGS="-s -w -extldflags=-Wl,-z,max-page-size=16384"

echo "==> go mod tidy"
go mod tidy

echo "==> gomobile bind (tags=$TAGS, abis=$ABIS)"
gomobile bind \
  -target "$ABIS" \
  -androidapi 26 \
  -javapkg com.tide.core \
  -tags "$TAGS" \
  -ldflags "$LDFLAGS" \
  -trimpath \
  -o "$OUT" \
  .

echo "==> done: $OUT"
ls -lh "$OUT"
