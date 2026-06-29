#!/bin/bash
# Automatic build script for MacLngSwitcher

set -e

# Change directory to script's location
cd "$(dirname "$0")"

echo "=== Building MacLngSwitcher ==="

# 1. Clean and create structure
echo "1. Preparing structure..."
rm -rf build MacLngSwitcher.app
mkdir -p build
mkdir -p MacLngSwitcher.app/Contents/MacOS
mkdir -p MacLngSwitcher.app/Contents/Resources

# 2. Generate icons
echo "2. Generating app icon..."
mkdir -p build/AppIcon.iconset
swift scripts/generate_icon.swift build/icon_master.png

# Resize master image to iconset dimensions for .icns
sips -z 16 16     build/icon_master.png --out build/AppIcon.iconset/icon_16x16.png
sips -z 32 32     build/icon_master.png --out build/AppIcon.iconset/icon_16x16@2x.png
sips -z 32 32     build/icon_master.png --out build/AppIcon.iconset/icon_32x32.png
sips -z 64 64     build/icon_master.png --out build/AppIcon.iconset/icon_32x32@2x.png
sips -z 128 128   build/icon_master.png --out build/AppIcon.iconset/icon_128x128.png
sips -z 256 256   build/icon_master.png --out build/AppIcon.iconset/icon_128x128@2x.png
sips -z 256 256   build/icon_master.png --out build/AppIcon.iconset/icon_256x256.png
sips -z 512 512   build/icon_master.png --out build/AppIcon.iconset/icon_256x256@2x.png
sips -z 512 512   build/icon_master.png --out build/AppIcon.iconset/icon_512x512.png
sips -z 1024 1024 build/icon_master.png --out build/AppIcon.iconset/icon_512x512@2x.png

# Create .icns file
iconutil -c icns build/AppIcon.iconset -o MacLngSwitcher.app/Contents/Resources/AppIcon.icns

# 3. Copy Info.plist
echo "3. Installing Info.plist..."
cp Resources/Info.plist MacLngSwitcher.app/Contents/Info.plist

# 4. Compile Swift source code
echo "4. Compiling source files..."
ARCH=$(uname -m)
SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)

# Build all .swift files in Sources
swiftc Sources/*.swift \
    -o MacLngSwitcher.app/Contents/MacOS/MacLngSwitcher \
    -target ${ARCH}-apple-macos13.0 \
    -sdk ${SDK_PATH} \
    -O

echo "=== Build completed successfully! ==="
echo "You can launch the app using: open MacLngSwitcher.app"
