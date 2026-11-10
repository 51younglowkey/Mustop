#!/bin/zsh
# Build Mustop → build/Mustop.app, then install it to ~/Applications/Mustop.app.
# Signed with the local self-signed identity "YoungBar Local Signing" (same as YoungBar),
# so the Accessibility grant survives rebuilds. Falls back to ad-hoc if the identity is missing
# (then the grant must be removed and re-added after every rebuild).
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Mustop.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -target arm64-apple-macos13 Sources/main.swift -o "$APP/Contents/MacOS/Mustop"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

IDENTITY="${MUSTOP_SIGN_IDENTITY:-YoungBar Local Signing}"
security find-identity -v -p codesigning | grep -q "\"$IDENTITY\"" || IDENTITY="-"
echo "signing with: $IDENTITY"
codesign --force --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP"

if [ "${1:-}" != "--no-install" ]; then
    mkdir -p "$HOME/Applications"
    pkill -x Mustop 2>/dev/null || true
    rm -rf "$HOME/Applications/Mustop.app"
    cp -R "$APP" "$HOME/Applications/Mustop.app"
    echo "installed: $HOME/Applications/Mustop.app"
fi
