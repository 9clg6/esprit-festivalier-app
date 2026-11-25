#!/bin/bash
# Archive the iOS app in Release and upload it to App Store Connect (TestFlight).
# Usage: TEAM_ID=<apple team id> scripts/testflight.sh [build-number]   (default build number: UTC timestamp)
# Needs the App Store Connect API key in ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY_PATH (kept out of this public repo).
# Signing is automatic and cloud-managed through that key (-allowProvisioningUpdates).
# PATH is reset for -exportArchive: Homebrew's rsync breaks the export copy step.
set -euo pipefail
cd "$(dirname "$0")/../ios"

: "${TEAM_ID:?set TEAM_ID}" "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_PRIVATE_KEY_PATH:?}"
BUILD_NUMBER="${1:-$(date -u +%y%m%d%H%M)}"
OUT=build/testflight
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$ASC_PRIVATE_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

rm -rf "$OUT" && mkdir -p "$OUT"
cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
PLIST

xcodegen generate --quiet
xcodebuild -project EspritFestivalier.xcodeproj -scheme EspritFestivalier -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/EspritFestivalier.xcarchive" \
  -derivedDataPath build/dd-release DEVELOPMENT_TEAM="$TEAM_ID" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  "${AUTH[@]}" archive > "$OUT/archive.log" 2>&1 \
  || { grep -E "error:" "$OUT/archive.log" | head -20; echo "ARCHIVE FAILED (log: ios/$OUT/archive.log)"; exit 1; }
echo "archive OK (build $BUILD_NUMBER)"

PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -exportArchive \
  -archivePath "$OUT/EspritFestivalier.xcarchive" -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -exportPath "$OUT/upload" "${AUTH[@]}" > "$OUT/export.log" 2>&1 \
  || { grep -E "error|description" "$OUT/export.log" | head -20; echo "UPLOAD FAILED (log: ios/$OUT/export.log)"; exit 1; }
echo "build $BUILD_NUMBER uploaded to App Store Connect"
