#!/bin/zsh
# Builds WheelFlip.app with just the Command Line Tools (xcode-select --install).
set -euo pipefail
cd "${0:A:h}"
[[ -d /Library/Developer/CommandLineTools ]] && export DEVELOPER_DIR=/Library/Developer/CommandLineTools

APP=build/WheelFlip.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

xcrun swiftc -O -target arm64-apple-macos13.0 \
  -framework AppKit -framework ApplicationServices -framework ServiceManagement \
  Sources/main.swift -o "$APP/Contents/MacOS/WheelFlip"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>dev.local.WheelFlip</string>
  <key>CFBundleName</key><string>WheelFlip</string>
  <key>CFBundleExecutable</key><string>WheelFlip</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - --identifier dev.local.WheelFlip "$APP"
"$APP/Contents/MacOS/WheelFlip" --selftest
echo "Built $APP"
