#!/bin/bash
set -euo pipefail

APP_NAME="BrewPackageManager"
VERSION="1.8.0"
DMG_NAME="${APP_NAME}-${VERSION}"
BUILD_CONFIGURATION="Release"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="${PROJECT_DIR}/BrewPackageManager/${APP_NAME}.xcodeproj"
DERIVED_DATA_PATH="${PROJECT_DIR}/.derived-release"
BUILT_APP="${DERIVED_DATA_PATH}/Build/Products/${BUILD_CONFIGURATION}/${APP_NAME}.app"
DMG_STAGING="${PROJECT_DIR}/dmg-staging"
DMG_DIR="${PROJECT_DIR}/dmg"
DMG_TEMP="${PROJECT_DIR}/${DMG_NAME}-temp.dmg"
DMG_FINAL="${DMG_DIR}/${DMG_NAME}.dmg"
MOUNT_DIR="/Volumes/${APP_NAME}"

echo "Building ${APP_NAME} (${BUILD_CONFIGURATION})..."
xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme "${APP_NAME}" \
    -configuration "${BUILD_CONFIGURATION}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    clean build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

if [ ! -d "${BUILT_APP}" ]; then
    echo "Error: Built app not found at ${BUILT_APP}"
    exit 1
fi

echo "Preparing DMG staging directory..."
rm -rf "${DMG_STAGING}"
mkdir -p "${DMG_STAGING}"

echo "Copying app to staging..."
cp -R "${BUILT_APP}" "${DMG_STAGING}/"

echo "Creating Applications symlink..."
ln -s /Applications "${DMG_STAGING}/Applications"

echo "Creating DMG image..."
mkdir -p "${DMG_DIR}"
rm -f "${DMG_TEMP}" "${DMG_FINAL}"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -format UDRW \
    "${DMG_TEMP}"

echo "Mounting DMG for customization..."
ATTACH_OUTPUT="$(hdiutil attach "${DMG_TEMP}")"
MOUNT_DIR="$(echo "${ATTACH_OUTPUT}" | awk -F'\t' '/\/Volumes\// {print $NF}' | tail -n 1)"
if [ -z "${MOUNT_DIR}" ]; then
    echo "Error: Could not determine mount directory from hdiutil output"
    echo "${ATTACH_OUTPUT}"
    exit 1
fi
DISK_NAME="$(basename "${MOUNT_DIR}")"
sleep 2

echo "Applying Finder layout..."
osascript <<EOF
tell application "Finder"
    tell disk "${DISK_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 900, 450}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 72
        set position of item "${APP_NAME}.app" of container window to {125, 175}
        set position of item "Applications" of container window to {375, 175}
        update without registering applications
        delay 1
    end tell
end tell
EOF

echo "Unmounting DMG..."
hdiutil detach "${MOUNT_DIR}"

echo "Compressing DMG..."
hdiutil convert "${DMG_TEMP}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_FINAL}"

echo "Cleaning temporary artifacts..."
rm -f "${DMG_TEMP}"
rm -rf "${DMG_STAGING}"

echo "DMG created: ${DMG_FINAL}"
ls -lh "${DMG_FINAL}"
