#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.3.0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$DIST_DIR/persistly-godot-sdk-$VERSION"
ZIP_PATH="$DIST_DIR/persistly-godot-sdk-$VERSION.zip"

rm -rf "$STAGE_DIR" "$ZIP_PATH"
mkdir -p "$STAGE_DIR"

cp -R "$ROOT_DIR/addons" "$STAGE_DIR/addons"
cp -R "$ROOT_DIR/assets" "$STAGE_DIR/assets"
cp -R "$ROOT_DIR/contracts" "$STAGE_DIR/contracts"
cp -R "$ROOT_DIR/templates" "$STAGE_DIR/templates"
cp "$ROOT_DIR/README.md" "$STAGE_DIR/README.md"
cp "$ROOT_DIR/CHANGELOG.md" "$STAGE_DIR/CHANGELOG.md"
cp "$ROOT_DIR/LICENSE" "$STAGE_DIR/LICENSE"
cp "$ROOT_DIR/SECURITY.md" "$STAGE_DIR/SECURITY.md"

(
  cd "$DIST_DIR"
  zip -qr "$(basename "$ZIP_PATH")" "$(basename "$STAGE_DIR")"
)

echo "$ZIP_PATH"
