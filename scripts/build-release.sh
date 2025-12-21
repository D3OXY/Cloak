#!/bin/bash

# Cloak Release Build Script
# Usage: ./scripts/build-release.sh [version]
# Example: ./scripts/build-release.sh 1.0.0

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project root
cd "$PROJECT_ROOT"

# Get version from argument or Info.plist
if [ -n "$1" ]; then
    VERSION="$1"
else
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Cloak/Info.plist 2>/dev/null || echo "1.0.0")
fi

echo -e "${GREEN}Building Cloak v${VERSION}${NC}"
echo "================================"

# Create dist directory
DIST_DIR="$PROJECT_ROOT/dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Step 1: Update version in Info.plist
echo -e "\n${YELLOW}Step 1: Setting version to ${VERSION}${NC}"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Cloak/Info.plist
echo "Version set in Info.plist"

# Step 2: Clean build
echo -e "\n${YELLOW}Step 2: Cleaning previous builds${NC}"
xcodebuild clean \
    -project Cloak.xcodeproj \
    -scheme Cloak \
    -configuration Release \
    -quiet

# Step 3: Build release
echo -e "\n${YELLOW}Step 3: Building release${NC}"
xcodebuild \
    -project Cloak.xcodeproj \
    -scheme Cloak \
    -configuration Release \
    build \
    CONFIGURATION_BUILD_DIR="$DIST_DIR" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    -quiet

if [ ! -d "$DIST_DIR/Cloak.app" ]; then
    echo -e "${RED}Build failed: Cloak.app not found${NC}"
    exit 1
fi

echo "Build successful: $DIST_DIR/Cloak.app"

# Step 4: Create DMG
echo -e "\n${YELLOW}Step 4: Creating DMG${NC}"
DMG_NAME="Cloak-${VERSION}.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

# Create staging folder with Applications shortcut
STAGING_DIR="$DIST_DIR/dmg-staging"
mkdir -p "$STAGING_DIR"
cp -R "$DIST_DIR/Cloak.app" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Create DMG
hdiutil create \
    -volname "Cloak" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" \
    -quiet

# Cleanup staging
rm -rf "$STAGING_DIR"

echo "DMG created: $DMG_PATH"

# Step 5: Create ZIP of app
echo -e "\n${YELLOW}Step 5: Creating ZIP archive${NC}"
ZIP_NAME="Cloak-${VERSION}-app.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

cd "$DIST_DIR"
zip -r -q "$ZIP_NAME" Cloak.app
cd "$PROJECT_ROOT"

echo "ZIP created: $ZIP_PATH"

# Step 6: Generate checksums
echo -e "\n${YELLOW}Step 6: Generating checksums${NC}"
cd "$DIST_DIR"
shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256"
cd "$PROJECT_ROOT"

echo "Checksums generated"

# Summary
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Output files in $DIST_DIR:"
echo "  - Cloak.app"
echo "  - $DMG_NAME"
echo "  - $ZIP_NAME"
echo "  - $DMG_NAME.sha256"
echo "  - $ZIP_NAME.sha256"
echo ""
echo "File sizes:"
ls -lh "$DIST_DIR"/*.dmg "$DIST_DIR"/*.zip 2>/dev/null | awk '{print "  " $9 ": " $5}'
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Test the app: open $DIST_DIR/Cloak.app"
echo "  2. Commit version bump: git add . && git commit -m 'Bump version to $VERSION'"
echo "  3. Create tag: git tag -a v$VERSION -m 'Release v$VERSION'"
echo "  4. Push: git push origin main && git push origin v$VERSION"
echo ""
