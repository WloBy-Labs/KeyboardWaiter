#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="KeyboardWaiter"
SIGNING_ENV_PATH="${SIGNING_ENV_PATH:-$HOME/Library/Application Support/$APP_NAME/signing/signing.env}"

if [[ -f "$SIGNING_ENV_PATH" ]]; then
    source "$SIGNING_ENV_PATH"
fi

BUILD_CONFIG="${BUILD_CONFIG:-release}"
APP_VERSION="${APP_VERSION:-0.8.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date '+%Y%m%d%H%M%S')}"
BUILD_TIMESTAMP="${BUILD_TIMESTAMP:-$(date '+%Y-%m-%d %H:%M:%S')}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
CODESIGN_IDENTITY_NAME="${CODESIGN_IDENTITY_NAME:-$CODESIGN_IDENTITY}"
CODESIGN_KEYCHAIN="${CODESIGN_KEYCHAIN:-}"
CODESIGN_KEYCHAIN_PASSWORD="${CODESIGN_KEYCHAIN_PASSWORD:-}"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$ROOT_DIR"

BUILD_CONFIG="$BUILD_CONFIG" "$ROOT_DIR/scripts/build_binary.sh"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp "$ROOT_DIR/.build/manual/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/$APP_NAME"

if [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
    mkdir -p "$CONTENTS_DIR/Resources"
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$CONTENTS_DIR/Resources/AppIcon.icns"
fi

plutil -replace CFBundleShortVersionString -string "$APP_VERSION" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"
plutil -replace KeyboardWaiterBuildTimestamp -string "$BUILD_TIMESTAMP" "$CONTENTS_DIR/Info.plist"

if command -v codesign >/dev/null 2>&1; then
    codesign_args=(--force --deep)

    if [[ -n "$CODESIGN_IDENTITY" ]]; then
        if [[ -n "$CODESIGN_KEYCHAIN" && -n "$CODESIGN_KEYCHAIN_PASSWORD" ]]; then
            security unlock-keychain -p "$CODESIGN_KEYCHAIN_PASSWORD" "$CODESIGN_KEYCHAIN" >/dev/null 2>&1 || true
        fi

        # A real identity is expected to be a Developer ID used for
        # notarized distribution, which requires a hardened runtime and a
        # secure timestamp. Ad-hoc/local identities skip both.
        if [[ "${CODESIGN_HARDENED_RUNTIME:-auto}" == "auto" ]]; then
            case "$CODESIGN_IDENTITY_NAME" in
                *"Developer ID"*) codesign_args+=(--options runtime --timestamp) ;;
                *) codesign_args+=(--timestamp=none) ;;
            esac
        elif [[ "$CODESIGN_HARDENED_RUNTIME" == "1" ]]; then
            codesign_args+=(--options runtime --timestamp)
        else
            codesign_args+=(--timestamp=none)
        fi

        codesign_args+=(--sign "$CODESIGN_IDENTITY")

        if [[ -n "$CODESIGN_KEYCHAIN" ]]; then
            codesign_args+=(--keychain "$CODESIGN_KEYCHAIN")
        fi

        echo "Signing $APP_DIR with ${CODESIGN_IDENTITY_NAME} (${CODESIGN_IDENTITY})"
    else
        codesign_args+=(--timestamp=none --sign -)
        echo "Warning: using ad-hoc signing. macOS privacy permissions may need to be re-granted after each rebuild."
        echo "Run scripts/bootstrap_local_signing.sh once to create a stable local signing identity."
    fi

    codesign "${codesign_args[@]}" "$APP_DIR"
    codesign --verify --deep --strict --verbose=2 "$APP_DIR"
fi

echo "Created $APP_DIR"
