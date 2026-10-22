#!/bin/zsh
# Builds the app and packages it as dist/PDF Merge <version>.dmg (drag-to-Applications layout).
set -euo pipefail
cd "${0:A:h}/.."

./scripts/build.sh
APP="dist/PDF Merge.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="dist/PDF Merge $VERSION.dmg"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/PDF Merge.app"
ln -s /Applications "$STAGE/Applications"
# Use the app icon for the mounted volume too.
cp Resources/AppIcon.icns "$STAGE/.VolumeIcon.icns"
SetFile -a C "$STAGE" 2>/dev/null || true

rm -f "$DMG"
hdiutil create -volname "PDF Merge" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 \
  -ov "$DMG" >/dev/null
echo "Created $(pwd)/$DMG ($(du -h "$DMG" | cut -f1))"
