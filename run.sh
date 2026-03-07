#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_BUNDLE="$PROJECT_DIR/McWhisper.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
BUNDLE_ID="com.mcwhisper.app"

# Build release binary
echo "Building McWhisper..."
swift build -c release --disable-sandbox --package-path "$PROJECT_DIR"

# Remove old bundle if present
if [ -d "$APP_BUNDLE" ]; then
    rm -r "$APP_BUNDLE"
fi

# Create .app bundle structure
mkdir -p "$MACOS_DIR"

# Copy binary
cp "$BUILD_DIR/McWhisper" "$MACOS_DIR/McWhisper"

# Write Info.plist
cat > "$CONTENTS_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>McWhisper</string>
    <key>CFBundleIdentifier</key>
    <string>com.mcwhisper.app</string>
    <key>CFBundleName</key>
    <string>McWhisper</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>McWhisper needs microphone access for speech-to-text transcription.</string>
</dict>
</plist>
PLIST

# Ad-hoc codesign
echo "Codesigning..."
codesign --deep --force -s - "$APP_BUNDLE"

# Kill any running instance
killall McWhisper 2>/dev/null || true

# Launch the app
echo "Launching McWhisper.app..."
"$MACOS_DIR/McWhisper" &
disown

echo "Done."
