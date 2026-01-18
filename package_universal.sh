#!/bin/bash

# 构建通用二进制版本（同时支持 Intel 和 Apple Silicon）

set -e

echo "🔨 Building for Apple Silicon (arm64)..."
swift build -c release --arch arm64

echo "🔨 Building for Intel (x86_64)..."
swift build -c release --arch x86_64

echo "📦 Creating Universal Binary..."

# 创建临时目录
mkdir -p .build/universal

# 使用 lipo 合并两个架构
lipo -create \
    .build/arm64-apple-macosx/release/Meowpal \
    .build/x86_64-apple-macosx/release/Meowpal \
    -output .build/universal/Meowpal

echo "✅ Universal binary created!"
lipo -info .build/universal/Meowpal

# 创建 App Bundle
echo ""
echo "📦 Creating App Bundle..."

APP_NAME="Meowpal.app"
rm -rf "$APP_NAME"
mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

# 复制可执行文件
echo "Copying executable..."
cp .build/universal/Meowpal "$APP_NAME/Contents/MacOS/"
chmod +x "$APP_NAME/Contents/MacOS/Meowpal"

# 复制精灵图
echo "Copying sprites..."
if [ -d "Sources/Meowpal/Resources" ]; then
    mkdir -p "$APP_NAME/Contents/Resources/sprites_aligned"
    cp -r Sources/Meowpal/Resources/* "$APP_NAME/Contents/Resources/sprites_aligned/"
    echo "✅ Sprites copied successfully"
else
    echo "⚠️  Warning: Sprites directory not found at Sources/Meowpal/Resources"
fi

# 复制应用图标
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$APP_NAME/Contents/Resources/"
    echo "✅ App icon copied"
fi

# 复制菜单栏模板图标
if [ -f "menubar_iconTemplate.png" ]; then
    cp menubar_iconTemplate.png "$APP_NAME/Contents/Resources/"
    cp menubar_iconTemplate@2x.png "$APP_NAME/Contents/Resources/"
    echo "✅ Menu bar icons copied"
fi

# 创建 Info.plist
echo "Creating Info.plist..."
cat > "$APP_NAME/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Meowpal</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.desktoppet.swift</string>
    <key>CFBundleName</key>
    <string>Meowpal</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>我们需要麦克风权限来进行语音转文字输入。</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>我们需要语音识别权限来将您的语音转换为文字。</string>
</dict>
</plist>
EOF

# 创建 Entitlements.plist
echo "Creating Entitlements.plist..."
cat > "Entitlements.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
EOF

# 签名
echo "✍️  Signing App Bundle..."
codesign --force --deep --sign - --entitlements Entitlements.plist "$APP_NAME"
echo "✅ App signed with entitlements"

# 清理临时文件
rm Entitlements.plist

echo ""
echo "✅ Universal Meowpal.app has been successfully created!"
echo "   Supports: Intel Mac (x86_64) and Apple Silicon (arm64)"
echo ""
echo "📦 To distribute:"
echo "   1. zip -r Meowpal-Universal.zip Meowpal.app"
echo "   2. Share the .zip file with your friends"
