#!/bin/zsh
set -euo pipefail

# 从 scripts/make_appicon.swift 重新生成 Resources/AppIcon.icns。
# 只在改图标设计时跑；产出的 .icns 已提交，平常构建不需要重新生成。
#
# 注意 make_appicon.swift 是**逐尺寸**渲染成 iconset 的，不是画一张大图再缩 ——
# 因为字标只在 128px 以上出现，小尺寸要用不同的画面。

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_DIR="$(mktemp -d /tmp/keyboardwaiter_icon.XXXXXX)"
cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

ICONSET="$TEMP_DIR/AppIcon.iconset"
OUT_ICNS="$ROOT_DIR/Resources/AppIcon.icns"

swiftc -O "$ROOT_DIR/scripts/make_appicon.swift" -o "$TEMP_DIR/make_appicon"
"$TEMP_DIR/make_appicon" "$ICONSET"

iconutil -c icns "$ICONSET" -o "$OUT_ICNS"
echo "Wrote $OUT_ICNS"
