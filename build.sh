#!/bin/bash
set -euo pipefail

APP_NAME="Click Highlight"
BUILD_DIR=".build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"

echo "Compiling..."
swiftc \
    Sources/main.swift \
    Sources/AppDelegate.swift \
    Sources/RippleWindowController.swift \
    Sources/RippleMetalView.swift \
    -o "$MACOS_DIR/click-highlight" \
    -framework Cocoa \
    -framework Metal \
    -framework MetalKit \
    -sdk "$(xcrun --show-sdk-path)" \
    -O

cp Info.plist "$APP_BUNDLE/Contents/Info.plist"

echo ""
echo "Built: $APP_BUNDLE"
echo "Run:   open '$APP_BUNDLE'"
