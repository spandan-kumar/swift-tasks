#!/bin/bash

APP_NAME="MenuBarTodo"
SOURCES="Sources/*.swift"
OUT_DIR="."

# Create the App Bundle Structure
mkdir -p "$OUT_DIR/$APP_NAME.app/Contents/MacOS"
mkdir -p "$OUT_DIR/$APP_NAME.app/Contents/Resources"

# Compile
echo "Compiling..."
swiftc $SOURCES -o "$OUT_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME" -target arm64-apple-macosx13.0 -framework ServiceManagement -framework Carbon

# Create Info.plist
echo "Creating Info.plist..."
cat > "$OUT_DIR/$APP_NAME.app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSRemindersUsageDescription</key>
    <string>This app needs access to your reminders to manage your tasks.</string>
</dict>
</plist>
EOF

echo "Done! App is at $OUT_DIR/$APP_NAME.app"
