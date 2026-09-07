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

# Signing identity, best first. Any stable certificate will do: macOS ties the
# Accessibility grant to the signature, so an ad-hoc build gets a new identity on
# every rebuild and the permission silently stops applying.
#
# MURMUR_SIGN_IDENTITY overrides. Otherwise prefer an Apple Development
# certificate, then a self-signed one named "Murmur Dev", which you can create in
# Keychain Access without Xcode or an Apple ID:
#   Keychain Access > Certificate Assistant > Create a Certificate…
#   Name: Murmur Dev   Identity Type: Self Signed Root
#   Certificate Type: Code Signing
IDENTITY="${MURMUR_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY=$(security find-identity -v -p codesigning | grep -o '"Apple Development[^"]*"' | head -1 | tr -d '"' || true)
fi
if [ -z "$IDENTITY" ]; then
  IDENTITY=$(security find-identity -v -p codesigning | grep -o '"Murmur Dev[^"]*"' | head -1 | tr -d '"' || true)
fi

codesign --force --sign "${IDENTITY:--}" "$APP"

if [ -n "$IDENTITY" ]; then
  echo "signed with: $IDENTITY (Accessibility grant survives rebuilds)"
else
  cat <<'NOTE'
note: ad-hoc signed. macOS will drop Murmur's Accessibility permission on every
      rebuild, and the toggle in System Settings will still look enabled.
      To fix permanently, create a self-signed certificate once:
        Keychain Access > Certificate Assistant > Create a Certificate…
        Name "Murmur Dev", Identity Type "Self Signed Root", Type "Code Signing"
      then rebuild. No Xcode or Apple ID required.
NOTE
fi

echo "built → $APP"
if [ "${1:-}" = "run" ]; then
  pkill -x Murmur 2>/dev/null || true
  sleep 0.3
  open "$APP"
fi
