#!/bin/zsh
# Builds WheelFlip.app with just the Command Line Tools (xcode-select --install).
set -euo pipefail
cd "${0:A:h}"
[[ -d /Library/Developer/CommandLineTools ]] && export DEVELOPER_DIR=/Library/Developer/CommandLineTools

APP=build/WheelFlip.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

# Universal binary: Apple Silicon + Intel.
for arch in arm64 x86_64; do
  xcrun swiftc -O -target $arch-apple-macos13.0 \
    -framework AppKit -framework ApplicationServices -framework ServiceManagement \
    Sources/main.swift -o "build/WheelFlip-$arch"
done
lipo -create build/WheelFlip-arm64 build/WheelFlip-x86_64 -output "$APP/Contents/MacOS/WheelFlip"
rm build/WheelFlip-arm64 build/WheelFlip-x86_64

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
