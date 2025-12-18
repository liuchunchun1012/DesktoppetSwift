#!/bin/bash

# Configuration
APP_NAME="DesktoppetSwift"
APP_DIR="${APP_NAME}.app"
SOURCES_DIR="Sources/DesktoppetSwift"
SPRITES_DIR="${SOURCES_DIR}/Resources"

# 1. Build the executable
echo "Building ${APP_NAME}..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "Build failed. Exiting."
    exit 1
fi

# 2. Create the App Bundle Structure
echo "Creating App Bundle..."
if [ -d "$APP_DIR" ]; then
    rm -rf "$APP_DIR"
fi

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 3. Copy the executable
echo "Copying executable..."
cp ".build/release/${APP_NAME}" "$APP_DIR/Contents/MacOS/"

# 4. Copy Resources
# Copy the sprites folder
echo "Copying sprites..."
if [ -d "$SPRITES_DIR" ]; then
    mkdir -p "$APP_DIR/Contents/Resources/sprites_aligned"
    cp -r "$SPRITES_DIR"/* "$APP_DIR/Contents/Resources/sprites_aligned/"
    echo "✅ Sprites copied successfully"
else
    echo "❌ Error: Sprites directory not found at $SPRITES_DIR"
    echo "Please ensure sprites are in ${SPRITES_DIR}"
    exit 1
fi

# Copy app icon
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$APP_DIR/Contents/Resources/"
    echo "✅ App icon copied"
fi

# 5. Create Info.plist
echo "Creating Info.plist..."
cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.desktoppet.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# LSUIElement = true makes it an agent app (no dock icon, menu bar only), which fits a status bar app.
# If the user wants a dock icon, we can remove LSUIElement or set it to false.
# Given "StatusBarController", it's likely a status bar app.

echo "${APP_NAME}.app has been successfully created!"
