#!/bin/bash
set -euo pipefail

VERSION="${1:?Usage: verify-dmg.sh VERSION DMG_PATH}"
DMG_PATH="${2:?Usage: verify-dmg.sh VERSION DMG_PATH}"
CHECKSUM_PATH="$DMG_PATH.sha256"
DMG_NAME="KeyRecorder-$VERSION.dmg"

[[ "$VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || { echo "Expected a release version such as 1.2.0" >&2; exit 2; }
[[ "$(basename "$DMG_PATH")" == "$DMG_NAME" ]] || { echo "Expected DMG named $DMG_NAME" >&2; exit 2; }

[[ -f "$DMG_PATH" ]] || { echo "DMG not found: $DMG_PATH" >&2; exit 1; }
[[ -f "$CHECKSUM_PATH" ]] || { echo "Checksum not found: $CHECKSUM_PATH" >&2; exit 1; }

EXPECTED_DIGEST=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
[[ "$(<"$CHECKSUM_PATH")" == "$EXPECTED_DIGEST  $DMG_NAME" ]] || { echo "Invalid checksum file: $CHECKSUM_PATH" >&2; exit 1; }
(
    cd "$(dirname "$DMG_PATH")"
    shasum -a 256 -c "$(basename "$CHECKSUM_PATH")"
)
hdiutil verify "$DMG_PATH" >/dev/null

ATTACH_PLIST=$(mktemp)
COPY_ROOT=$(mktemp -d)
MOUNT_POINT=""
cleanup() {
    [[ -z "$MOUNT_POINT" ]] || hdiutil detach "$MOUNT_POINT" -quiet || true
    rm -f "$ATTACH_PLIST"
    rm -rf "$COPY_ROOT"
}
trap cleanup EXIT

hdiutil attach -readonly -nobrowse -plist "$DMG_PATH" > "$ATTACH_PLIST"
for index in {0..7}; do
    MOUNT_POINT=$(/usr/libexec/PlistBuddy -c "Print :system-entities:$index:mount-point" "$ATTACH_PLIST" 2>/dev/null || true)
    [[ -z "$MOUNT_POINT" ]] || break
done
[[ -n "$MOUNT_POINT" ]] || { echo "Unable to determine DMG mount point" >&2; exit 1; }

MOUNTED_APP="$MOUNT_POINT/Key Recorder.app"
COPIED_APP="$COPY_ROOT/Key Recorder.app"
[[ -L "$MOUNT_POINT/Applications" && "$(readlink "$MOUNT_POINT/Applications")" == "/Applications" ]] || { echo "Applications shortcut is missing or invalid" >&2; exit 1; }
[[ -d "$MOUNTED_APP" ]] || { echo "Key Recorder.app is missing from DMG" >&2; exit 1; }
ditto "$MOUNTED_APP" "$COPIED_APP"

codesign --verify --deep --strict --verbose=2 "$COPIED_APP"
codesign -d -r- "$COPIED_APP" >/dev/null 2>&1

plutil -lint "$COPIED_APP/Contents/Info.plist" >/dev/null
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$COPIED_APP/Contents/Info.plist")
[[ "$BUNDLE_ID" == "romainfrezier.key-recorder" ]] || { echo "Unexpected bundle identifier: $BUNDLE_ID" >&2; exit 1; }
BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$COPIED_APP/Contents/Info.plist")
[[ "$BUNDLE_VERSION" == "$VERSION" ]] || { echo "Expected version $VERSION, got $BUNDLE_VERSION" >&2; exit 1; }

ARCHS=$(lipo -archs "$COPIED_APP/Contents/MacOS/key-recorder")
[[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]] || { echo "Expected arm64 and x86_64, got: $ARCHS" >&2; exit 1; }

if [[ ${REQUIRE_GATEKEEPER:-0} == 1 ]]; then
    xcrun stapler validate "$DMG_PATH"
    spctl --assess --type exec --verbose=4 "$COPIED_APP"
    spctl --assess --type open --verbose=4 --context context:primary-signature "$DMG_PATH"
fi

echo "Verified checksum, DMG, Applications shortcut, app identity, signature, version $VERSION, and universal executable"
