#!/usr/bin/env bash
set -euo pipefail

# Build the Iris DMG installer.
#
# Requires create-dmg:  brew install create-dmg
# Requires Pillow + numpy for the background regen:  pip install Pillow numpy
#
# Usage: installer/build_dmg.sh [/path/to/Iris.app]
#   Defaults to ./Iris.app (or $APP). Output DMG is ./Iris.dmg (or $OUT).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="${1:-${APP:-Iris.app}}"
OUT="${OUT:-Iris.dmg}"

if [[ ! -d "$APP" ]]; then
  echo "error: app bundle not found: $APP" >&2
  echo "usage: $0 /path/to/Iris.app" >&2
  exit 1
fi

# Regenerate the background so it always matches the geometry below.
python3 installer/gen_dmg_bg.py

rm -f "$OUT"

create-dmg \
  --volname "Iris" \
  --window-size 460 660 \
  --icon-size 135 \
  --app-drop-link 230 100 \
  --icon "Iris.app" 230 464 \
  --background installer/dmg_background.png \
  "$OUT" \
  "$APP"

echo "wrote $OUT"
