#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$PROJECT_DIR/outputs/InputPin.app"
mkdir -p "$APP/Contents/MacOS" "$PROJECT_DIR/scratch/module-cache"
xcrun swiftc -O -swift-version 5 -target arm64-apple-macosx13.0 -module-cache-path "$PROJECT_DIR/scratch/module-cache" "$PROJECT_DIR/src/main.swift" -o "$APP/Contents/MacOS/InputPin" -framework Cocoa -framework Carbon -framework ServiceManagement
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.daltan.InputPin</string>
<key>CFBundleExecutable</key><string>InputPin</string>
<key>CFBundleName</key><string>InputPin</string>
<key>CFBundleDisplayName</key><string>InputPin</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
printf '%s\n' "$APP"
