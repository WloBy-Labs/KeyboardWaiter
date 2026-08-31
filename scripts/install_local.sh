#!/bin/zsh
set -euo pipefail

# 本地开发安装。用法： ./scripts/install_local.sh [版本号]
#
# 为什么要有这个脚本：输入监控（TCC）的授权记录认的是「签名身份 + bundle id + 路径」。
# 只要这三样不变，重装多少次都不用重新授权。所以这里刻意做到：
#
#   1. 不覆盖签名配置 —— 用 signing.env 里那张证书，和 CI 发布的 Release 是同一个身份
#   2. 不删除 .app —— 用 rsync 就地更新内容，保留 bundle 路径
#
# 反例（会导致每次都要重新授权）：
#   SIGNING_ENV_PATH=/dev/null CODESIGN_IDENTITY=<别的证书> ./scripts/package_app.sh
#   rm -rf /Applications/KeyboardWaiter.app && ditto ...

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="KeyboardWaiter"
INSTALL_PATH="/Applications/$APP_NAME.app"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT_DIR/Resources/Info.plist")-dev}"

cd "$ROOT_DIR"

echo "==> 打包 $VERSION（使用 signing.env 里配置的签名身份）"
BUILD_CONFIG=release APP_VERSION="$VERSION" ./scripts/package_app.sh >/dev/null

NEW_AUTHORITY="$(codesign -dvvv "dist/$APP_NAME.app" 2>&1 | grep '^Authority=' | head -1 || true)"
echo "==> 新包签名：${NEW_AUTHORITY:-（未签名）}"

if [[ -d "$INSTALL_PATH" ]]; then
    OLD_AUTHORITY="$(codesign -dvvv "$INSTALL_PATH" 2>&1 | grep '^Authority=' | head -1 || true)"
    if [[ "$OLD_AUTHORITY" != "$NEW_AUTHORITY" ]]; then
        echo "!!  签名身份和已安装的不一致，装完需要重新授权输入监控"
        echo "    已安装：${OLD_AUTHORITY:-（未签名）}"
    fi
fi

if pgrep -f "$INSTALL_PATH" >/dev/null 2>&1; then
    echo "==> 退出正在运行的实例"
    pkill -TERM -f "$INSTALL_PATH" || true
    sleep 2
fi

echo "==> 就地更新 $INSTALL_PATH（不删除 bundle，保住授权记录）"
mkdir -p "$INSTALL_PATH"
rsync -a --delete "dist/$APP_NAME.app/" "$INSTALL_PATH/"
xattr -dr com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true

echo "==> 启动"
open -a "$INSTALL_PATH"

echo "==> 完成：$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INSTALL_PATH/Contents/Info.plist")"
