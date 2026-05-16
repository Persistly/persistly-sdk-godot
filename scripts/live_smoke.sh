#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${PERSISTLY_RUNTIME_KEY:-}" ]]; then
  echo "PERSISTLY_RUNTIME_KEY must be set to a dev/test runtime key." >&2
  exit 1
fi

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$GODOT_BIN" ]]; then
  echo "Godot binary not found: $GODOT_BIN" >&2
  exit 1
fi

"$GODOT_BIN" --headless --script scripts/live_smoke.gd
