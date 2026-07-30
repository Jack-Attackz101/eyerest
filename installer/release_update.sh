#!/usr/bin/env bash
# release_update.sh — package a signed Iris update and stamp docs/appcast.xml
#
# Usage:
#   installer/release_update.sh <version> [build-number]
#
# Examples:
#   installer/release_update.sh 1.0.1
#   installer/release_update.sh 1.0.1 2
#
# Prerequisites (one-time, done during Sparkle setup):
#   1. EdDSA key generated:  <sparkle-bin>/generate_keys
#      Private key is stored in your macOS Keychain automatically.
#      Public key was placed in Iris/Info.plist SUPublicEDKey.
#   2. GitHub Pages enabled for docs/ folder on main branch.
#
# The private key is NEVER written to disk or read by this script.
# sign_update retrieves it directly from your macOS Keychain.
# If it cannot find the key it will print an error and exit non-zero.
#
# Output:
#   Iris-<version>.zip       — attach this to the GitHub Release
#   docs/appcast.xml         — updated with new <item>; commit and push
#
# After running this script:
#   git add docs/appcast.xml
#   git commit -m "release: appcast for v<version>"
#   git push origin main
#   Create a GitHub Release tagged v<version> and upload Iris-<version>.zip

set -euo pipefail

VERSION="${1:?Usage: $0 <version> [build-number]}"
BUILD="${2:-}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
cd "$REPO_ROOT"

APP="Iris.app"
ZIP="Iris-${VERSION}.zip"
APPCAST="docs/appcast.xml"
GITHUB_REPO="Jack-Attackz101/eyerest"
RELEASE_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${ZIP}"

# ── 1. Find sign_update ─────────────────────────────────────────────────────
SIGN_UPDATE=""
# Check Xcode DerivedData (after resolving packages)
if [ -z "$SIGN_UPDATE" ]; then
    SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData -name sign_update \
        -path "*/Sparkle/*" -type f 2>/dev/null | head -1 || true)
fi
# Check a local sparkle/ directory in the repo root
if [ -z "$SIGN_UPDATE" ] && [ -f "sparkle/bin/sign_update" ]; then
    SIGN_UPDATE="$REPO_ROOT/sparkle/bin/sign_update"
fi
# Check PATH
if [ -z "$SIGN_UPDATE" ] && command -v sign_update &>/dev/null; then
    SIGN_UPDATE="sign_update"
fi
if [ -z "$SIGN_UPDATE" ]; then
    echo ""
    echo "error: sign_update not found."
    echo "  1. Open the project in Xcode to resolve the Sparkle package, then re-run."
    echo "  2. Or download Sparkle from github.com/sparkle-project/Sparkle/releases"
    echo "     and extract it to ${REPO_ROOT}/sparkle/"
    echo ""
    exit 1
fi
echo "Using sign_update: $SIGN_UPDATE"

# ── 2. Verify Iris.app exists and is signed ──────────────────────────────────
if [ ! -d "$APP" ]; then
    echo "error: $APP not found in $REPO_ROOT"
    echo "  Run the full release checklist (archive → sign → notarize) first."
    exit 1
fi
if ! codesign --verify --deep --strict "$APP" &>/dev/null; then
    echo "error: $APP is not signed. Sign and notarize before packaging an update."
    exit 1
fi

# ── 3. Zip the app ───────────────────────────────────────────────────────────
echo "==> Zipping $APP → $ZIP"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
BYTE_LENGTH=$(wc -c < "$ZIP" | tr -d ' ')
echo "    $BYTE_LENGTH bytes"

# ── 4. Sign with EdDSA (key read from Keychain automatically) ────────────────
echo "==> Signing $ZIP with EdDSA …"
SIGNATURE=$("$SIGN_UPDATE" "$ZIP")
echo "    sparkle:edSignature = $SIGNATURE"

# ── 5. Determine build number ────────────────────────────────────────────────
if [ -z "$BUILD" ]; then
    # Extract from the app bundle
    BUILD=$(defaults read "$REPO_ROOT/$APP/Contents/Info" CFBundleVersion 2>/dev/null || echo "")
fi
if [ -z "$BUILD" ]; then
    echo "warning: could not determine build number; defaulting to 1"
    BUILD="1"
fi

# ── 6. Stamp appcast.xml ─────────────────────────────────────────────────────
PUBDATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")

NEW_ITEM="        <item>
            <title>Iris ${VERSION}</title>
            <pubDate>${PUBDATE}</pubDate>
            <sparkle:releaseNotesLink>https://jack-attackz101.github.io/eyerest/</sparkle:releaseNotesLink>
            <enclosure
                url=\"${RELEASE_URL}\"
                sparkle:version=\"${BUILD}\"
                sparkle:shortVersionString=\"${VERSION}\"
                length=\"${BYTE_LENGTH}\"
                type=\"application/octet-stream\"
                sparkle:edSignature=\"${SIGNATURE}\" />
        </item>"

# Insert the new <item> immediately after the opening <channel> block's last <language> tag.
# Uses a temp file to avoid in-place sed portability issues.
TMPFILE=$(mktemp)
awk -v item="$NEW_ITEM" '
    /<language>/ { print; print ""; print item; next }
    { print }
' "$APPCAST" > "$TMPFILE"
mv "$TMPFILE" "$APPCAST"

# ── 7. Summary ───────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  Iris ${VERSION} update package ready                               ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  Next steps:                                                     ║"
echo "║                                                                  ║"
echo "║  1. git add docs/appcast.xml                                     ║"
echo "║     git commit -m \"release: appcast for v${VERSION}\"             ║"
echo "║     git push origin main                                         ║"
echo "║     (GitHub Pages re-publishes within ~60 seconds)               ║"
echo "║                                                                  ║"
echo "║  2. Create a GitHub Release:                                     ║"
echo "║       Tag:   v${VERSION}                                         ║"
echo "║       Title: Iris ${VERSION}                                     ║"
echo "║       Upload: ${ZIP}                                             ║"
echo "║       gh release create v${VERSION} ${ZIP} --title \"Iris ${VERSION}\"  ║"
echo "║                                                                  ║"
echo "║  ⚠ Updates silently fail on unsigned builds (no Autoupdate XPC) ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
