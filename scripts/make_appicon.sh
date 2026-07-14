#!/bin/zsh
set -euo pipefail

# Regenerates Resources/AppIcon.icns from scripts/make_appicon.swift.
# Run this only when changing the icon design; the resulting .icns is
# committed so normal builds do not need to regenerate it.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_DIR="$(mktemp -d /tmp/keyboard_waiter_icon.XXXXXX)"
cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

BASE_PNG="$TEMP_DIR/AppIcon-1024.png"
ICONSET="$TEMP_DIR/AppIcon.iconset"
OUT_ICNS="$ROOT_DIR/Resources/AppIcon.icns"

swiftc -O "$ROOT_DIR/scripts/make_appicon.swift" -o "$TEMP_DIR/make_appicon"
"$TEMP_DIR/make_appicon" "$BASE_PNG"

mkdir -p "$ICONSET"
for spec in "16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" \
            "128:128x128" "256:128x128@2x" "256:256x256" "512:256x256@2x" \
            "512:512x512" "1024:512x512@2x"; do
    px="${spec%%:*}"
    label="${spec##*:}"
    sips -z "$px" "$px" "$BASE_PNG" --out "$ICONSET/icon_${label}.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$OUT_ICNS"
echo "Wrote $OUT_ICNS"
