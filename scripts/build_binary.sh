#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/manual"
ARCH="$(uname -m)"
TARGET_TRIPLE="$ARCH-apple-macos13.0"
BUILD_CONFIG="${BUILD_CONFIG:-debug}"
MODULE_CACHE_DIR="$ROOT_DIR/.build/module-cache"

mkdir -p "$BUILD_DIR"
mkdir -p "$MODULE_CACHE_DIR"

SWIFTC_FLAGS=(
    -module-cache-path "$MODULE_CACHE_DIR"
    -target "$TARGET_TRIPLE"
    -framework AppKit
    -framework ApplicationServices
    -framework Carbon
    -lsqlite3
)

if [[ "$BUILD_CONFIG" == "release" ]]; then
    SWIFTC_FLAGS+=(-O)
else
    SWIFTC_FLAGS+=(-g)
fi

swiftc \
    "${SWIFTC_FLAGS[@]}" \
    "$ROOT_DIR"/Sources/KeyboardWaiterCore/*.swift \
    "$ROOT_DIR"/Sources/KeyboardWaiterApp/main.swift \
    -o "$BUILD_DIR/KeyboardWaiter"

echo "Built $BUILD_DIR/KeyboardWaiter"
