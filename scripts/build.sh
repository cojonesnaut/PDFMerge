#!/bin/zsh
# Builds "PDF Merge.app" into ./dist (or /Applications with --install). Works with Command Line Tools alone; uses Xcode when available.
set -euo pipefail
cd "${0:A:h}/.."

# Prefer an installed Xcode even if xcode-select still points at the Command Line Tools.
if [[ -z "${DEVELOPER_DIR:-}" ]] && ! xcode-select -p | grep -q Xcode.app && [[ -d /Applications/Xcode.app ]] \
   && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --find actool >/dev/null 2>&1; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

# The macOS 27 SDK turns SwiftUI's @State into a macro whose plugin ships only with Xcode.
# Without Xcode, fall back to the newest older SDK that still has the property wrapper.
if [[ -z "${SDKROOT:-}" ]] && [[ "${DEVELOPER_DIR:-$(xcode-select -p)}" != *Xcode.app* ]]; then
  for sdk in /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk; do
    [[ -d $sdk ]] && export SDKROOT=$sdk && break
  done
fi

swift build -c release --arch arm64 --arch x86_64 2>&1 | { grep -vE "search path .* not found" || true; }
(( ${pipestatus[1]} == 0 )) || { echo "Build failed"; exit 1; }
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/PDFMerge
[[ -f $BIN ]] || { echo "Build failed"; exit 1; }

APP="dist/PDF Merge.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/PDFMerge"
strip -x "$APP/Contents/MacOS/PDFMerge"
# SwiftPM records the deployment target as the SDK version too; macOS uses the SDK version to
# decide whether an app gets the current (Liquid Glass) design, so stamp the real one.
SDK_VERSION=$(xcrun --sdk macosx --show-sdk-version 2>/dev/null || true)
if [[ -n $SDK_VERSION ]]; then
  vtool -set-build-version macos 14.0 "$SDK_VERSION" -replace \
    -output "$APP/Contents/MacOS/PDFMerge" "$APP/Contents/MacOS/PDFMerge" 2>/dev/null || true
fi
cp Resources/Info.plist "$APP/Contents/Info.plist"

# App icon: regenerate when the artwork script changes.
if [[ ! -f Resources/AppIcon.icns || scripts/make_icon.swift -nt Resources/AppIcon.icns ]]; then
  TMP=$(mktemp -d)
  swift scripts/make_icon.swift "$TMP"
  mkdir "$TMP/AppIcon.iconset"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$TMP/AppIcon.iconset" -o Resources/AppIcon.icns
  rm -rf Resources/AppIcon.icon && cp -R "$TMP/AppIcon.icon" Resources/AppIcon.icon
  rm -rf "$TMP"
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# With Xcode installed, also compile the layered Icon Composer icon so macOS renders real
# Liquid Glass (default, dark, clear and tinted). The .icns above stays as the fallback.
if xcrun --find actool >/dev/null 2>&1; then
  TMP=$(mktemp -d)
  if xcrun actool Resources/AppIcon.icon --compile "$TMP" --platform macosx \
       --minimum-deployment-target 14.0 --app-icon AppIcon --include-all-app-icons \
       --output-partial-info-plist "$TMP/partial.plist" >/dev/null 2>&1; then
    # Keep our full-resolution .icns for macOS 14–25; actool's own fallback stops at 256 px.
    cp "$TMP/Assets.car" "$APP/Contents/Resources/Assets.car"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || true
    echo "Compiled Liquid Glass icon (Assets.car)"
  else
    echo "actool couldn't compile AppIcon.icon; using AppIcon.icns"
  fi
  rm -rf "$TMP"
fi

codesign --force --deep --sign - "$APP"
echo "Built $(pwd)/$APP ($(du -sh "$APP" | cut -f1))"

# ./scripts/build.sh --install  moves the app into /Applications (replacing an older copy).
if [[ "${1:-}" == "--install" ]]; then
  osascript -e 'tell application "PDF Merge" to quit' >/dev/null 2>&1 || true
  rm -rf "/Applications/PDF Merge.app"
  mv "$APP" "/Applications/PDF Merge.app"
  echo "Installed /Applications/PDF Merge.app"
fi
