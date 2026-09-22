#!/bin/bash
set -euo pipefail

VERSION="${1:?Usage: package-dmg.sh VERSION APP_PATH OUTPUT_PATH}"
APP_PATH="${2:?Usage: package-dmg.sh VERSION APP_PATH OUTPUT_PATH}"
OUTPUT_PATH="${3:?Usage: package-dmg.sh VERSION APP_PATH OUTPUT_PATH}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-}"
ENTITLEMENTS="${ENTITLEMENTS:-$(cd "$(dirname "$0")/.." && pwd)/key-recorder/key_recorder.entitlements}"

[[ "$VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || { echo "Expected a release version such as 1.2.0" >&2; exit 2; }
[[ "$(basename "$OUTPUT_PATH")" == "KeyRecorder-$VERSION.dmg" ]] || { echo "Expected output named KeyRecorder-$VERSION.dmg" >&2; exit 2; }
if [[ -n "$NOTARYTOOL_PROFILE" && "$CODESIGN_IDENTITY" == "-" ]]; then
    echo "Notarization requires a Developer ID Application identity" >&2
    exit 2
fi

[[ -d "$APP_PATH" ]] || { echo "Application not found: $APP_PATH" >&2; exit 1; }
[[ -f "$ENTITLEMENTS" ]] || { echo "Entitlements not found: $ENTITLEMENTS" >&2; exit 1; }
mkdir -p "$(dirname "$OUTPUT_PATH")"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

ditto "$APP_PATH" "$staging/Key Recorder.app"
ln -s /Applications "$staging/Applications"

PACKAGED_APP="$staging/Key Recorder.app"
PACKAGED_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PACKAGED_APP/Contents/Info.plist")
[[ "$PACKAGED_VERSION" == "$VERSION" ]] || {
    echo "Application version $PACKAGED_VERSION does not match requested version $VERSION" >&2
    exit 1
}

if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign - --entitlements "$ENTITLEMENTS" "$PACKAGED_APP"
else
    codesign --force --sign "$CODESIGN_IDENTITY" --timestamp --options runtime --entitlements "$ENTITLEMENTS" "$PACKAGED_APP"
fi
codesign --verify --deep --strict --verbose=2 "$PACKAGED_APP"

hdiutil create \
    -volname "Key Recorder $VERSION" \
    -srcfolder "$staging" \
    -ov \
    -format UDZO \
    "$OUTPUT_PATH" >/dev/null

if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
    codesign --force --sign "$CODESIGN_IDENTITY" --timestamp "$OUTPUT_PATH"
fi
if [[ -n "$NOTARYTOOL_PROFILE" ]]; then
    xcrun notarytool submit "$OUTPUT_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
    xcrun stapler staple "$OUTPUT_PATH"
    xcrun stapler validate "$OUTPUT_PATH"
fi

hdiutil verify "$OUTPUT_PATH" >/dev/null
(
    cd "$(dirname "$OUTPUT_PATH")"
    shasum -a 256 "$(basename "$OUTPUT_PATH")" > "$(basename "$OUTPUT_PATH").sha256"
    shasum -a 256 -c "$(basename "$OUTPUT_PATH").sha256"
)

printf '%s\n%s\n' "$OUTPUT_PATH" "$OUTPUT_PATH.sha256"
