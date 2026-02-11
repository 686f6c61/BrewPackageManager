#!/bin/bash
# Build script for BrewPackageManager without App Sandbox.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="${PROJECT_DIR}/BrewPackageManager/BrewPackageManager.xcodeproj"
DERIVED_DATA_PATH="${PROJECT_DIR}/.derived-debug"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug/BrewPackageManager.app"

echo "Building BrewPackageManager (Debug)..."
echo "Disabling App Sandbox to allow Homebrew command execution..."

xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme BrewPackageManager \
    -configuration Debug \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    ENABLE_APP_SANDBOX=NO \
    clean build

echo ""
echo "Build succeeded."
echo "App location: ${APP_PATH}"
echo ""
echo "To run: open \"${APP_PATH}\""
