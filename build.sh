#!/bin/bash
# Builds ClaudePet.app from Sources/ using swiftc (no full Xcode needed).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/ClaudePet.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"

rm -rf "$APP"
mkdir -p "$MACOS" "$RES"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>ClaudePet</string>
  <key>CFBundleDisplayName</key><string>Claude Pet</string>
  <key>CFBundleIdentifier</key><string>com.claudepet.app</string>
  <key>CFBundleExecutable</key><string>ClaudePet</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "Compiling..."
swiftc -O \
  "$ROOT/Sources/ClaudePet/main.swift" \
  -o "$MACOS/ClaudePet" \
  -framework AppKit -framework SwiftUI -framework Foundation

codesign --force --sign - "$APP" 2>/dev/null || true
echo "Built: $APP"
