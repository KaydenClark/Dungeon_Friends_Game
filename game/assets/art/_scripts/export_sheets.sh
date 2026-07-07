#!/bin/sh
# M1.1 batch-export wrapper (T-003). Runs the Aseprite Lua exporter from the
# game/ project root. Fails with a clear message while Aseprite isn't
# installed yet (see TASKBOARD.md T-003 - install decision is Kayden's).
set -e
cd "$(dirname "$0")/../../.."   # -> game/

ASEPRITE="/Applications/Aseprite.app/Contents/MacOS/aseprite"
if [ ! -x "$ASEPRITE" ]; then
  ASEPRITE="$(command -v aseprite || true)"
fi
if [ -z "$ASEPRITE" ] || [ ! -x "$ASEPRITE" ]; then
  echo "export_sheets.sh: Aseprite not found." >&2
  echo "  Install it (App Store / aseprite.org, ~\$20) or 'brew install aseprite'," >&2
  echo "  then re-run. Until then, regenerate the test art with:" >&2
  echo "  Godot --headless --path . --script assets/art/_scripts/generate_test_tileset.gd" >&2
  exit 1
fi

exec "$ASEPRITE" -b --script assets/art/_scripts/export_sheets.lua
