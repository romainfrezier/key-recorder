#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

expect_failure() {
    local message="$1"
    shift
    if "$@" >"$WORK/output" 2>&1; then
        echo "Expected failure: $*" >&2
        exit 1
    fi
    if ! grep -Fq "$message" "$WORK/output"; then
        cat "$WORK/output" >&2
        echo "Expected diagnostic: $message" >&2
        exit 1
    fi
}

for version in 1.2 v1.2.3 01.2.3 1.2.3-beta; do
    expect_failure "Expected a release version" "$ROOT/scripts/package-dmg.sh" "$version" "$WORK/app" "$WORK/output.dmg"
    expect_failure "Expected a release version" "$ROOT/scripts/verify-dmg.sh" "$version" "$WORK/output.dmg"
done
expect_failure "Expected output named" "$ROOT/scripts/package-dmg.sh" 1.2.3 "$WORK/app" "$WORK/latest.dmg"
expect_failure "Expected DMG named" "$ROOT/scripts/verify-dmg.sh" 1.2.3 "$WORK/latest.dmg"
expect_failure "Notarization requires" env CODESIGN_IDENTITY=- NOTARYTOOL_PROFILE=test \
    "$ROOT/scripts/package-dmg.sh" 1.2.3 "$WORK/app" "$WORK/KeyRecorder-1.2.3.dmg"

# A checksum for another file must never validate the distributed DMG.
printf 'fixture' > "$WORK/KeyRecorder-1.2.3.dmg"
printf 'other' > "$WORK/other.dmg"
(cd "$WORK" && shasum -a 256 other.dmg > KeyRecorder-1.2.3.dmg.sha256)
expect_failure "Invalid checksum file" "$ROOT/scripts/verify-dmg.sh" 1.2.3 "$WORK/KeyRecorder-1.2.3.dmg"
(cd "$WORK" && shasum -a 256 KeyRecorder-1.2.3.dmg > KeyRecorder-1.2.3.dmg.sha256)
printf 'tampered' >> "$WORK/KeyRecorder-1.2.3.dmg"
expect_failure "Invalid checksum file" "$ROOT/scripts/verify-dmg.sh" 1.2.3 "$WORK/KeyRecorder-1.2.3.dmg"

echo "Distribution validation checks passed"
