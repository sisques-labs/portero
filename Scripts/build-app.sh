#!/usr/bin/env bash
# Assembles a double-clickable Portero.app from the SPM release build.
# No Xcode required — only Command Line Tools.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Portero"
RELEASE_BIN=".build/release/${APP_NAME}"
APP_BUNDLE=".build/${APP_NAME}.app"

swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$RELEASE_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"

codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built $APP_BUNDLE"
