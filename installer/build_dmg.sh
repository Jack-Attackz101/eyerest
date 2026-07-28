#!/usr/bin/env bash
set -euo pipefail

# Build Iris.dmg with the approved portrait willow layout.
#
# Prerequisites:
#   brew install create-dmg
#   a signed, stapled Iris.app at the repository root
#
# Steps: regenerate the DMG background, then run create-dmg.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
cd "$REPO_ROOT"

APP="Iris.app"
DMG="Iris.dmg"
BACKGROUND="installer/dmg_background.png"

# 1. Regenerate the background (460x660 willow + arrow + one line of text).
python3 installer/gen_dmg_bg.py

# 2. Require create-dmg.
if ! command -v create-dmg >/dev/null 2>&1; then
    echo "error: create-dmg not found. Install it with: brew install create-dmg" >&2
    exit 1
fi

# 3. Require the app bundle to package.
if [[ ! -d "$APP" ]]; then
    echo "error: $APP not found in $REPO_ROOT. Build and export the app first." >&2
    exit 1
fi

# 4. Start clean.
rm -f "$DMG"

# 5. Build the DMG.
#    Applications folder sits at the TOP (y=100), Iris sits BELOW it (y=464),
#    so the hand-drawn arrow in the background points upward from app to folder.
create-dmg \
    --volname "Iris" \
    --window-size 460 660 \
    --icon-size 135 \
    --app-drop-link 230 100 \
    --icon "Iris.app" 230 464 \
    --background "$BACKGROUND" \
    "$DMG" \
    "$APP"

echo "wrote $REPO_ROOT/$DMG"
