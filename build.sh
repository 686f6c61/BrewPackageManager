#!/bin/bash
# Build script for BrewPackageManager without App Sandbox

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR/BrewPackageManager"

echo "🔨 Building BrewPackageManager..."
echo "📦 Disabling App Sandbox to allow Homebrew command execution..."

xcodebuild \
    -project BrewPackageManager.xcodeproj \
    -scheme BrewPackageManager \
    -configuration Debug \
    ENABLE_APP_SANDBOX=NO \
    clean build

echo ""
echo "✅ Build succeeded!"
echo "📍 App location: ~/Library/Developer/Xcode/DerivedData/BrewPackageManager-*/Build/Products/Debug/BrewPackageManager.app"
echo ""
echo "🚀 To run: open ~/Library/Developer/Xcode/DerivedData/BrewPackageManager-bupfwhlthlwasaebrplbxtjhofih/Build/Products/Debug/BrewPackageManager.app"
