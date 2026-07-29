#!/usr/bin/env bash
set -euo pipefail

# sign_and_notarize.sh
#
# Why this script exists:
#   An unsigned (or un-notarized) Iris.app / Iris.dmg makes macOS Gatekeeper
#   show "Iris is damaged and can't be opened" to anyone who downloads it,
#   even though nothing is actually wrong with the file. The fix is to
#   codesign the app with a Developer ID Application identity, submit it to
#   Apple's notary service, and staple the resulting ticket to the app so
#   Gatekeeper accepts it offline. This script automates that whole flow.
#
# Usage:
#   export APPLE_ID="dad@example.com"
#   export TEAM_ID="AB12CD34EF"
#   installer/sign_and_notarize.sh \
#     "Developer ID Application: Dad Name (AB12CD34EF)" \
#     <app-specific-password>
#
# No certificates, passwords, or other secrets are hardcoded anywhere in
# this script — the signing identity and app-specific password are passed
# in as arguments, and the Apple ID / Team ID are read from the environment.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
cd "$REPO_ROOT"

APP="Iris.app"
ZIP="Iris.zip"
ENTITLEMENTS="Iris/Iris.entitlements"

# --- Argument and environment validation --------------------------------

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <developer-id-identity> <app-specific-password>" >&2
    echo "  <developer-id-identity>    e.g. \"Developer ID Application: Dad Name (AB12CD34EF)\"" >&2
    echo "  <app-specific-password>    generated at appleid.apple.com -> Sign-In & Security -> App-Specific Passwords" >&2
    echo "" >&2
    echo "Also requires the following environment variables to be set:" >&2
    echo "  APPLE_ID   - the Apple ID email used for notarization" >&2
    echo "  TEAM_ID    - the 10-character Apple Developer Team ID" >&2
    exit 1
fi

DEV_ID_IDENTITY="$1"
APP_SPECIFIC_PASSWORD="$2"

if [[ -z "${APPLE_ID:-}" ]]; then
    echo "error: APPLE_ID environment variable is not set." >&2
    echo "       export APPLE_ID=\"your-apple-id@example.com\" and re-run." >&2
    exit 1
fi

if [[ -z "${TEAM_ID:-}" ]]; then
    echo "error: TEAM_ID environment variable is not set." >&2
    echo "       export TEAM_ID=\"AB12CD34EF\" (see developer.apple.com -> Account) and re-run." >&2
    exit 1
fi

if [[ ! -d "$APP" ]]; then
    echo "error: $APP not found in $REPO_ROOT." >&2
    echo "       Export the archived app from Xcode Organizer (Distribute App ->" >&2
    echo "       Developer ID) or copy the Release build to the repo root first." >&2
    exit 1
fi

# --- Step 1: Codesign with the Developer ID Application identity -------

echo "==> Step 1: Codesigning $APP with hardened runtime ..."

CODESIGN_ARGS=(
    --force
    --options runtime
    --timestamp
    --sign "$DEV_ID_IDENTITY"
)

if [[ -f "$ENTITLEMENTS" ]]; then
    echo "    Using entitlements file: $ENTITLEMENTS"
    CODESIGN_ARGS+=(--entitlements "$ENTITLEMENTS")
else
    # No entitlements file found in the repo — sign without one and note it
    # here rather than guessing at entitlements that don't exist.
    echo "    No entitlements file found at $ENTITLEMENTS; signing without --entitlements."
fi

codesign "${CODESIGN_ARGS[@]}" "$APP" || {
    echo "ERROR: codesign failed on $APP" >&2
    echo "       Check that \"$DEV_ID_IDENTITY\" matches a valid, non-expired" >&2
    echo "       \"Developer ID Application\" certificate in your Keychain" >&2
    echo "       (Keychain Access -> My Certificates)." >&2
    exit 1
}

# --- Step 2: Verify the signature ---------------------------------------

echo "==> Step 2: Verifying signature ..."

codesign --verify --deep --strict --verbose=2 "$APP" || {
    echo "ERROR: codesign verification failed on $APP" >&2
    echo "       The app may contain unsigned nested binaries/frameworks, or" >&2
    echo "       the signature may not cover every bundled component. Re-run" >&2
    echo "       codesign --verify --deep --strict --verbose=4 $APP for details." >&2
    exit 1
}

# --- Step 3: Zip the app for notary submission --------------------------

echo "==> Step 3: Zipping $APP for notarization submission ..."

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP" || {
    echo "ERROR: ditto failed to create $ZIP from $APP" >&2
    echo "       Check available disk space and that $APP is not open/locked." >&2
    exit 1
}

# --- Step 4: Submit to Apple's notary service ---------------------------

echo "==> Step 4: Submitting $ZIP to notarytool (this can take 2-10 min) ..."

xcrun notarytool submit "$ZIP" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --wait || {
    echo "ERROR: notarytool submit failed or was rejected." >&2
    echo "       Check APPLE_ID, TEAM_ID, and the app-specific password are" >&2
    echo "       correct, and that $DEV_ID_IDENTITY has notarization access" >&2
    echo "       for this Team ID. Run the following for the full log:" >&2
    echo "         xcrun notarytool log <submission-id> --apple-id \"\$APPLE_ID\" --team-id \"\$TEAM_ID\" --password <app-specific-password>" >&2
    exit 1
}

# --- Step 5: Staple the notarization ticket and validate ----------------

echo "==> Step 5: Stapling notarization ticket to $APP ..."

xcrun stapler staple "$APP" || {
    echo "ERROR: stapler failed to staple $APP" >&2
    echo "       If notarization just finished, wait 60s and retry:" >&2
    echo "         xcrun stapler staple $APP" >&2
    exit 1
}

echo "==> Validating stapled ticket ..."

xcrun stapler validate "$APP" || {
    echo "ERROR: stapler validate failed on $APP" >&2
    echo "       The staple did not take. Re-run step 5, or re-submit for" >&2
    echo "       notarization if the ticket has expired." >&2
    exit 1
}

spctl -a -vvv -t install "$APP" || {
    echo "ERROR: spctl rejected $APP" >&2
    echo "       Expected output containing \"accepted\" and" >&2
    echo "       \"source=Notarized Developer ID\". If it's missing, the app" >&2
    echo "       is not correctly signed/notarized/stapled." >&2
    exit 1
}

echo ""
echo "✓ $APP is signed, notarized, and stapled."
