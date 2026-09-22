# Packaging and distribution

Key Recorder uses a versioned DMG and SHA-256 checksum, following the
S3Workbench distribution workflow. It retains its universal **Intel + Apple
Silicon** binary and requires **macOS 15.1 or later**.

The public build is ad hoc signed and not notarized. There is no Homebrew
channel or in-app updater. Installing a new version replaces the application;
it does not remove preferences, exported recordings, or the local session
archive. macOS may require Input Monitoring permission again after an update.

## Build and verify a DMG

Use Xcode 16.2 or later with its license accepted. Set `VERSION` to the version
in the Xcode project's `MARKETING_VERSION`; the scripts reject mismatched
versions and filenames. Run from the repository root:

```sh
VERSION=1.2.0 # Example: use the version being prepared.
xcodebuild test -project key-recorder.xcodeproj -scheme key-recorder \
  -destination 'platform=macOS' -only-testing:key-recorderTests \
  -parallel-testing-enabled NO
xcodebuild archive -project key-recorder.xcodeproj -scheme key-recorder \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath "$PWD/build/KeyRecorder.xcarchive" \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO
scripts/package-dmg.sh "$VERSION" \
  "$PWD/build/KeyRecorder.xcarchive/Products/Applications/key-recorder.app" \
  "$PWD/build/KeyRecorder-$VERSION.dmg"
scripts/verify-dmg.sh "$VERSION" "$PWD/build/KeyRecorder-$VERSION.dmg"
```

`package-dmg.sh` signs a staged copy, adds the Applications shortcut, creates
`KeyRecorder-X.Y.Z.dmg`, verifies the image, and writes the matching
`.dmg.sha256`. It leaves the original archive unchanged.

`verify-dmg.sh` requires the checksum to name that exact DMG, verifies the image,
mounts it read-only, and copies the app into a temporary directory. It checks
the Applications shortcut, full code signature, Info.plist, bundle identifier,
version, and both executable architectures. Temporary files and mounts are
cleaned up on exit.

Run `scripts/test-distribution.sh` to check rejection of invalid versions,
unversioned filenames, mismatched or tampered checksums, and notarization
without a signing identity. The Quality workflow runs these checks too.

## CI artifacts and publication

The **Quality** workflow runs on pull requests, pushes to `main`, version tags,
and manual dispatch. After tests, it creates and verifies the universal archive
and uploads both files as `KeyRecorder-X.Y.Z-universal`. Tag builds additionally
require `vX.Y.Z` to match the app's version. A passing branch build is a review
artifact, not a published release.

To publish an authorized release:

1. Update the app version and changelog, review the final changes, and verify
   the checks on the intended `main` commit.
2. Create and push the matching annotated `vX.Y.Z` tag from that commit.
3. Wait for the tag's Quality run, then download its artifact by **run ID**.
4. Verify and manually test the downloaded DMG. Publish those exact files,
   without rebuilding or replacing already published release assets.

```sh
VERSION=1.2.0 # Example: replace with the approved release version.
RUN_ID=123456789 # Replace with the successful tag run's ID.
gh run download "$RUN_ID" --repo romainfrezier/key-recorder \
  --name "KeyRecorder-$VERSION-universal" --dir "build/release-$VERSION"
scripts/verify-dmg.sh "$VERSION" "build/release-$VERSION/KeyRecorder-$VERSION.dmg"
gh release create "v$VERSION" \
  "build/release-$VERSION/KeyRecorder-$VERSION.dmg" \
  "build/release-$VERSION/KeyRecorder-$VERSION.dmg.sha256" \
  --repo romainfrezier/key-recorder --verify-tag \
  --title "Key Recorder $VERSION" --notes-file release-notes.md
```

The workflow has read-only repository permissions and does not publish releases.
Before publication, test installing the downloaded app, opening it through
Gatekeeper, granting Input Monitoring, detecting keys, recording simultaneous
presses, stopping early, and reopening the CSV. Verify an update preserves
existing settings and archived sessions. CI packaging checks do not prove those
interactive checks or an Intel launch on a real Mac.

## Optional Developer ID signing and notarization

For an Apple-trusted build, use an installed **Developer ID Application**
certificate and an existing `notarytool` keychain profile. Do not store
credentials in the repository. The default CI produces the ad hoc build; it
does not have signing or notarization credentials configured.

```sh
VERSION=1.2.0 # Example: must match the archive's app version.
CODESIGN_IDENTITY='Developer ID Application: Name (TEAMID)' \
NOTARYTOOL_PROFILE=key-recorder-notary \
  scripts/package-dmg.sh "$VERSION" \
  "$PWD/build/KeyRecorder.xcarchive/Products/Applications/key-recorder.app" \
  "$PWD/build/KeyRecorder-$VERSION.dmg"
REQUIRE_GATEKEEPER=1 scripts/verify-dmg.sh "$VERSION" \
  "$PWD/build/KeyRecorder-$VERSION.dmg"
```

This signs the app with Hardened Runtime and a timestamp, signs the DMG,
submits it to Apple, waits for acceptance, and staples and validates the
notarization ticket **before** calculating SHA-256. The stricter verification
also checks the ticket and Gatekeeper assessment of the app and disk image.
Publish the exact notarized files after verification; the ad hoc CI artifacts
are not substitutes. Without the certificate and profile, do not describe a
build as notarized or trusted by Gatekeeper.
