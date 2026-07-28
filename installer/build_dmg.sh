#!/usr/bin/env bash
#
# Build the Iris DMG installer.
#
#   Applications folder (drop link)  TOP     -> 230, 100
#   Iris.app icon                    BOTTOM  -> 230, 464
#   The hand-drawn arrow points up from the app to the folder.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT"

APP="Iris.app"
DMG="Iris.dmg"
BG="installer/dmg_background.png"

command -v create-dmg >/dev/null 2>&1 || {
    echo "error: create-dmg not found (install with: brew install create-dmg)" >&2
    exit 1
}
[ -d "$APP" ] || {
    echo "error: $APP not found in $ROOT" >&2
    exit 1
}

# Regenerate the background from the source assets.
python3 installer/gen_dmg_bg.py

rm -f "$DMG"

# create-dmg copies the *contents* of the source folder into the image,
# so stage the app in a temp dir that holds only Iris.app.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"

create-dmg \
    --volname "Iris" \
    --window-size 460 660 \
    --icon-size 135 \
    --app-drop-link 230 100 \
    --icon "Iris.app" 230 464 \
    --background "$BG" \
    "$DMG" \
    "$STAGE"

echo "built $DMG"
