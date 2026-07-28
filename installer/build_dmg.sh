#!/usr/bin/env bash
set -euo pipefail

# Build Iris.dmg with the approved window layout.
#
# Prerequisites:
#   - create-dmg (brew install create-dmg)
#   - a signed, stapled Iris.app at the repository root
#
# Steps: regenerate the DMG background, then run create-dmg.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
cd "$REPO_ROOT"

APP="Iris.app"
DMG="Iris.dmg"
BACKGROUND="installer/dmg_background.png"

# 1. Regenerate the DMG background.
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
create-dmg \
    --volname "Iris" \
    --window-size 540 340 \
    --icon-size 100 \
    --icon "Iris.app" 135 150 \
    --app-drop-link 405 150 \
    --background "$BACKGROUND" \
    "$DMG" \
    "$APP"

echo "wrote $REPO_ROOT/$DMG"
