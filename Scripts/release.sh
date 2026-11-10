#!/bin/zsh
# Build a universal (arm64 + x86_64) Mustop.app and zip it into dist/ for a GitHub release.
# Usage: zsh Scripts/release.sh            (version is read from Info.plist)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
OUT=build/release
APP=$OUT/Mustop.app
rm -rf "$OUT" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist

swiftc -O -target arm64-apple-macos13  Sources/main.swift -o "$OUT/Mustop-arm64"
swiftc -O -target x86_64-apple-macos13 Sources/main.swift -o "$OUT/Mustop-x86_64"
lipo -create "$OUT/Mustop-arm64" "$OUT/Mustop-x86_64" -output "$APP/Contents/MacOS/Mustop"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

IDENTITY="${MUSTOP_SIGN_IDENTITY:-YoungBar Local Signing}"
security find-identity -v -p codesigning | grep -q "\"$IDENTITY\"" || IDENTITY="-"
echo "signing with: $IDENTITY"
codesign --force --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP"

ZIP="dist/Mustop-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP"
