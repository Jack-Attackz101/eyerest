#!/usr/bin/env bash
set -euo pipefail

# Build Iris.dmg with the approved portrait willow layout.
#
# Prerequisites:
#   brew install create-dmg
#   a signed, stapled Iris.app at the repository root
#   (run installer/sign_and_notarize.sh before this script)
#
# Usage (unsigned — will trigger "Iris is damaged" for downloaders):
#   ./installer/build_dmg.sh
#
# Usage (signed + stapled — safe for distribution):
#   DEV_ID="Developer ID Application: Your Name (TEAMID)" ./installer/build_dmg.sh
#
# Steps: regenerate the DMG background, build the DMG, then optionally sign it.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
cd "$REPO_ROOT"

DEV_ID="${DEV_ID:-}"
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

# 4. Warn if the app inside is not signed — don't block the build, just alert.
if ! codesign --verify --deep --strict "$APP" &>/dev/null; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  WARNING: Iris.app is not signed or fails verification.     ║"
    echo "║  Run installer/sign_and_notarize.sh before this script or   ║"
    echo "║  the finished DMG will trigger Gatekeeper for every user.   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
fi

# 5. Start clean.
rm -f "$DMG"

# 6. Build the DMG.
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

echo "wrote $REPO_ROOT/$DMG  ($(wc -c < "$DMG" | tr -d ' ') bytes)"

# 7. Sign and staple the DMG itself (only when DEV_ID is provided).
if [[ -n "$DEV_ID" ]]; then
    echo ""
    echo "==> Signing DMG with: $DEV_ID"
    codesign --force --sign "$DEV_ID" --timestamp "$DMG" || {
        echo "ERROR: failed to sign $DMG"
        exit 1
    }

    echo "==> Stapling notarization ticket to DMG ..."
    xcrun stapler staple "$DMG" || {
        echo "ERROR: stapler failed on $DMG"
        echo "       If notarization just finished, wait 60 s and retry:"
        echo "         xcrun stapler staple $DMG"
        exit 1
    }

    xcrun stapler validate "$DMG"

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✓ Iris.dmg is signed and stapled.                          ║"
    echo "║    Anyone in the world can download and open it.            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
else
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  WARNING: DMG IS UNSIGNED                                   ║"
    echo "║                                                              ║"
    echo "║  DEV_ID is not set. The DMG was built without a code        ║"
    echo "║  signature or notarization ticket.                          ║"
    echo "║                                                              ║"
    echo "║  ANYONE WHO DOWNLOADS THIS WILL SEE:                        ║"
    echo "║    \"Iris is damaged and can't be opened.\"                   ║"
    echo "║                                                              ║"
    echo "║  To produce a releasable DMG:                               ║"
    echo "║    1. Run installer/sign_and_notarize.sh first              ║"
    echo "║    2. Re-run with DEV_ID set (see usage comment at top)     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
fi
