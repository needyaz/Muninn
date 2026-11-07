#!/usr/bin/env bash
#
# Build a Developer ID-signed, notarized Muninn for download outside the Mac App Store and attach it to a GitHub Release.
# Run through `make github-release`, which sets the environment:
#
#   VERSION=1.0.64 BUILD=64 TEAM=ABCDE12345 scripts/direct_release.sh
#
# Steps: archive in Release with the stamped version, export with a Developer ID options plist, zip, notarize
# (notarytool, waiting for Apple's verdict), staple the ticket, re-zip, verify with Gatekeeper's own check, then
# `gh release create` (or upload over an existing release for that tag).
#
# Notarization credentials: either a notarytool keychain profile (NOTARY_PROFILE, created once with
# `xcrun notarytool store-credentials`) or an App Store Connect API key (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILEPATH).
set -euo pipefail

: "${VERSION:?VERSION is required (1.0.<build>)}"
: "${BUILD:?BUILD is required (the commit count)}"
: "${TEAM:?TEAM is required (your Apple team ID)}"

if [ -n "${NOTARY_PROFILE:-}" ]; then
  notary_auth=(--keychain-profile "$NOTARY_PROFILE")
elif [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -f "${ASC_KEY_FILEPATH:-}" ]; then
  notary_auth=(--key "$ASC_KEY_FILEPATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID")
else
  echo "✗ set NOTARY_PROFILE, or ASC_KEY_ID + ASC_ISSUER_ID + ASC_KEY_FILEPATH, for notarization (see DISTRIBUTION.md)" >&2
  exit 1
fi

out=build/direct
archive="$out/Muninn.xcarchive"
zip="$out/Muninn-$VERSION.zip"
mkdir -p "$out"
rm -f "$zip"

# The export options name the team, so they are written here rather than committed.
cat > "$out/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>destination</key>
	<string>export</string>
	<key>teamID</key>
	<string>$TEAM</string>
	<key>signingStyle</key>
	<string>automatic</string>
</dict>
</plist>
PLIST

echo "→ archiving Muninn $VERSION (build $BUILD)"
xcodebuild archive -quiet \
  -project Muninn.xcodeproj -scheme Muninn -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$archive" \
  CURRENT_PROJECT_VERSION="$BUILD" MARKETING_VERSION="$VERSION" \
  MUNINN_BUNDLE_ID="${BUNDLE_ID:-blue.luci.Muninn}" DEVELOPMENT_TEAM="$TEAM" \
  -allowProvisioningUpdates

echo "→ exporting with Developer ID"
rm -rf "$out/export"
xcodebuild -exportArchive -quiet \
  -archivePath "$archive" -exportPath "$out/export" \
  -exportOptionsPlist "$out/ExportOptions.plist" \
  -allowProvisioningUpdates
app="$out/export/Muninn.app"
codesign --verify --deep --strict "$app"

echo "→ notarizing (Apple usually takes a few minutes)"
ditto -c -k --keepParent "$app" "$out/notarize.zip"
xcrun notarytool submit "$out/notarize.zip" --wait "${notary_auth[@]}"
rm -f "$out/notarize.zip"

echo "→ stapling and checking"
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
ditto -c -k --keepParent "$app" "$zip"

tag="v$VERSION"
notes="Muninn $VERSION for macOS 14 or later, signed and notarized: unzip, move Muninn.app to Applications and open it. This build does not update itself: download a newer release to update. Muninn makes no network connections."
if gh release view "$tag" >/dev/null 2>&1; then
  echo "→ uploading to the existing release $tag"
  gh release upload "$tag" "$zip" --clobber
else
  echo "→ creating release $tag"
  gh release create "$tag" "$zip" --title "Muninn $VERSION" --notes "$notes" --target "$(git rev-parse HEAD)"
fi
echo "✓ Muninn $VERSION notarized and attached to release $tag"
