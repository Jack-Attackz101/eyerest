#!/usr/bin/env bash
#
# build_dmg.sh — build the Iris Release .app and package it into Iris.dmg.
# Run on macOS. This is the end-to-end DMG build command.
#
# Requires:
#   * Xcode + command-line tools (xcodebuild)
#   * create-dmg          -> brew install create-dmg
#   * python3 + Pillow    -> pip3 install pillow   (renders the DMG background)
#
# Usage:
#   ./build_dmg.sh
#
# Optional environment overrides (set these to ship a real, shippable build):
#   SIGN_ID          Developer ID Application identity (enables signing + hardened runtime)
#   TEAM_ID          Apple Developer Team ID
#   NOTARY_PROFILE   notarytool keychain profile name (enables notarise + staple)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

APP_NAME="Iris"
SCHEME="Iris"
BUILD_DIR="$ROOT/build"
ARCHIVE="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP="$EXPORT_DIR/$APP_NAME.app"
DMG="$ROOT/$APP_NAME.dmg"
BG="$ROOT/installer/dmg_background.png"

echo "==> Generating DMG background (540x340, minimal chalk design)"
python3 installer/gen_dmg_bg.py

echo "==> Cleaning previous build"
rm -rf "$BUILD_DIR" "$DMG"
mkdir -p "$EXPORT_DIR"

echo "==> Archiving $SCHEME (Release)"
SIGN_FLAGS=()
if [[ -n "${SIGN_ID:-}" ]]; then
  SIGN_FLAGS=(
    CODE_SIGN_IDENTITY="$SIGN_ID"
    CODE_SIGN_STYLE=Manual
    OTHER_CODE_SIGN_FLAGS="--options=runtime --timestamp"
  )
  [[ -n "${TEAM_ID:-}" ]] && SIGN_FLAGS+=(DEVELOPMENT_TEAM="$TEAM_ID")
else
  echo "    (SIGN_ID unset -> unsigned build; do NOT ship this one)"
  SIGN_FLAGS=(CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO)
fi

xcodebuild archive \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  "${SIGN_FLAGS[@]}"

echo "==> Exporting $APP_NAME.app from the archive"
cp -R "$ARCHIVE/Products/Applications/$APP_NAME.app" "$APP"

# Notarise the app before packaging (needs a signed build)
if [[ -n "${NOTARY_PROFILE:-}" && -n "${SIGN_ID:-}" ]]; then
  echo "==> Notarising $APP_NAME.app"
  ditto -c -k --keepParent "$APP" "$BUILD_DIR/$APP_NAME.zip"
  xcrun notarytool submit "$BUILD_DIR/$APP_NAME.zip" \
    --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
fi

echo "==> Packaging $DMG (540x340; Iris @135,150  Applications @405,150)"
create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 \
  --window-size 540 340 \
  --icon-size 128 \
  --background "$BG" \
  --icon "$APP_NAME.app" 135 150 \
  --app-drop-link 405 150 \
  --no-internet-enable \
  "$DMG" \
  "$EXPORT_DIR"

# Staple the notarisation ticket to the finished DMG too
if [[ -n "${NOTARY_PROFILE:-}" && -n "${SIGN_ID:-}" ]]; then
  echo "==> Notarising $DMG"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

echo "==> Done: $DMG"
