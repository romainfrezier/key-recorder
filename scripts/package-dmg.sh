#!/bin/bash
set -euo pipefail

VERSION="${1:?Usage: package-dmg.sh VERSION APP_PATH OUTPUT_PATH}"
APP_PATH="${2:?Usage: package-dmg.sh VERSION APP_PATH OUTPUT_PATH}"
OUTPUT_PATH="${3:?Usage: package-dmg.sh VERSION APP_PATH OUTPUT_PATH}"

[[ -d "$APP_PATH" ]] || { echo "Application not found: $APP_PATH" >&2; exit 1; }
mkdir -p "$(dirname "$OUTPUT_PATH")"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

ditto "$APP_PATH" "$staging/Key Recorder.app"
ln -s /Applications "$staging/Applications"

hdiutil create \
    -volname "Key Recorder $VERSION" \
    -srcfolder "$staging" \
    -ov \
    -format UDZO \
    "$OUTPUT_PATH" >/dev/null

echo "Created $OUTPUT_PATH"
