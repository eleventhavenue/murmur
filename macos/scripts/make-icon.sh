#!/bin/bash
# Builds Murmur/Resources/Assets.xcassets/AppIcon.appiconset from a rendered 1024px PNG.
set -euo pipefail
cd "$(dirname "$0")/.."
SET="Murmur/Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$SET" build
swift scripts/render-icon.swift build/icon-1024.png
cp build/icon-1024.png "$SET/icon_512x512@2x.png"
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon-1024.png --out "$SET/icon_${s}x${s}.png" >/dev/null
  d=$((s*2))
  if [ $s -ne 512 ]; then sips -z $d $d build/icon-1024.png --out "$SET/icon_${s}x${s}@2x.png" >/dev/null; fi
done
cat > "$SET/Contents.json" <<'JSON'
{ "images": [
  {"size":"16x16","idiom":"mac","filename":"icon_16x16.png","scale":"1x"},
  {"size":"16x16","idiom":"mac","filename":"icon_16x16@2x.png","scale":"2x"},
  {"size":"32x32","idiom":"mac","filename":"icon_32x32.png","scale":"1x"},
  {"size":"32x32","idiom":"mac","filename":"icon_32x32@2x.png","scale":"2x"},
  {"size":"128x128","idiom":"mac","filename":"icon_128x128.png","scale":"1x"},
  {"size":"128x128","idiom":"mac","filename":"icon_128x128@2x.png","scale":"2x"},
  {"size":"256x256","idiom":"mac","filename":"icon_256x256.png","scale":"1x"},
  {"size":"256x256","idiom":"mac","filename":"icon_256x256@2x.png","scale":"2x"},
  {"size":"512x512","idiom":"mac","filename":"icon_512x512.png","scale":"1x"},
  {"size":"512x512","idiom":"mac","filename":"icon_512x512@2x.png","scale":"2x"}
], "info": {"version":1,"author":"xcode"} }
JSON
echo '{ "info": {"version":1,"author":"xcode"} }' > Murmur/Resources/Assets.xcassets/Contents.json
echo "icon ready"
