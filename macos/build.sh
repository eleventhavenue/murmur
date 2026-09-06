#!/bin/bash
# Build Murmur.app. Needs only the Command Line Tools (swiftc + iconutil), no Xcode.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Murmur.app"
SDK="$(xcrun --show-sdk-path)"

echo "compiling…"
mkdir -p .build
swiftc -swift-version 5 -O -target arm64-apple-macos14.0 -sdk "$SDK" \
  -o .build/Murmur $(find Murmur/Sources -name '*.swift')

# Icon: build AppIcon.icns from the asset catalog PNGs (actool is Xcode-only, iconutil is not).
if [ ! -f .build/AppIcon.icns ]; then
  echo "building icon…"
  rm -rf .build/AppIcon.iconset && mkdir -p .build/AppIcon.iconset
  for n in 16x16 16x16@2x 32x32 32x32@2x 128x128 128x128@2x 256x256 256x256@2x 512x512 512x512@2x; do
    cp "Murmur/Resources/Assets.xcassets/AppIcon.appiconset/icon_$n.png" ".build/AppIcon.iconset/icon_$n.png"
  done
  iconutil -c icns .build/AppIcon.iconset -o .build/AppIcon.icns
fi

echo "assembling bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/Murmur "$APP/Contents/MacOS/Murmur"
cp .build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Instrument Serif, the brand display face, loaded via ATSApplicationFontsPath.
cp -R Murmur/Resources/Fonts "$APP/Contents/Resources/Fonts"
sed -e 's/$(EXECUTABLE_NAME)/Murmur/' -e 's/$(DEVELOPMENT_LANGUAGE)/en/' \
  Murmur/Resources/Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Sign with a real identity when one exists so macOS keeps the Accessibility grant across rebuilds.
# Without one we fall back to ad-hoc, and macOS forgets the grant on every rebuild.
IDENTITY=$(security find-identity -v -p codesigning | grep -o '"Apple Development[^"]*"' | head -1 | tr -d '"' || true)
codesign --force --sign "${IDENTITY:--}" "$APP"
[ -n "$IDENTITY" ] || echo "note: ad-hoc signed (no Apple Development identity) — macOS will ask for Accessibility again after each rebuild"

echo "built → $APP"
if [ "${1:-}" = "run" ]; then
  pkill -x Murmur 2>/dev/null || true
  sleep 0.3
  open "$APP"
fi
