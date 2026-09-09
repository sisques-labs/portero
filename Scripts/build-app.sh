#!/usr/bin/env bash
# Assembles a double-clickable Portero.app from the SPM release build.
# No Xcode required — only Command Line Tools.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Portero"
VERSION="${VERSION:-0.0.0-dev}"
RELEASE_BIN=".build/release/${APP_NAME}"
APP_BUNDLE=".build/${APP_NAME}.app"
ZIP_PATH=".build/${APP_NAME}-v${VERSION}.app.zip"

swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$RELEASE_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"

# Stamp the bundle's own copy of Info.plist with the release version before
# signing — stamping after codesign would invalidate the signature (see
# homebrew-release-train design.md, decision 3).
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$APP_BUNDLE/Contents/Info.plist"

# The icon must land in the bundle before codesign — mutating Contents/ after
# signing invalidates the signature (same constraint as the version stamp above;
# see homebrew-release-train design.md, decision 3).
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP_BUNDLE"

# ditto preserves the code signature; a plain zip does not (see design.md).
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "Built $APP_BUNDLE"
echo "Packaged $ZIP_PATH"
