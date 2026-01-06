#!/bin/bash
set -e

APP_NAME="BrewPackageManager"
VERSION="1.6.0"
DMG_NAME="${APP_NAME}-${VERSION}"
BUILD_DIR="BrewPackageManager"

echo "Building ${APP_NAME} for Release..."
cd "${BUILD_DIR}"
xcodebuild -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    clean build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO

BUILT_APP="${HOME}/Library/Developer/Xcode/DerivedData/${APP_NAME}-bupfwhlthlwasaebrplbxtjhofih/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "$BUILT_APP" ]; then
    echo "Error: Built app not found at ${BUILT_APP}"
    exit 1
fi

echo "Creating DMG staging directory..."
DMG_STAGING="../dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

echo "Copying app to staging..."
cp -R "$BUILT_APP" "$DMG_STAGING/"

echo "Creating Applications symlink..."
ln -s /Applications "$DMG_STAGING/Applications"

echo "Creating DMG..."
cd ..

# Create dmg directory if it doesn't exist
mkdir -p dmg

DMG_TEMP="${DMG_NAME}-temp.dmg"
DMG_FINAL="dmg/${DMG_NAME}.dmg"

rm -f "$DMG_TEMP" "$DMG_FINAL"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "dmg-staging" \
    -ov -format UDRW \
    "$DMG_TEMP"

echo "Mounting DMG for customization..."
MOUNT_DIR="/Volumes/${APP_NAME}"
hdiutil attach "$DMG_TEMP"

# Wait for Finder to recognize the mounted volume
sleep 2

echo "Setting DMG window properties..."
osascript <<EOF
tell application "Finder"
    tell disk "${APP_NAME}"
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
hdiutil detach "$MOUNT_DIR"

echo "Converting to compressed DMG..."
hdiutil convert "$DMG_TEMP" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_FINAL"

echo "Cleaning up..."
rm -f "$DMG_TEMP"
rm -rf "dmg-staging"

echo "DMG created: ${DMG_FINAL}"
ls -lh "$DMG_FINAL"
