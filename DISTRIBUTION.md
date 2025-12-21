# Cloak Distribution Guide

This guide covers how to build, version, and distribute Cloak for macOS.

## Table of Contents

- [Versioning](#versioning)
- [Building the App](#building-the-app)
  - [Using Xcode UI](#using-xcode-ui)
  - [Using Terminal](#using-terminal)
- [Creating a DMG](#creating-a-dmg)
- [GitHub Releases](#github-releases)
  - [Manual Release](#manual-release)
  - [Automated Release](#automated-release-github-actions)
- [Installation Instructions for Users](#installation-instructions-for-users)

---

## Versioning

Cloak uses semantic versioning: `MAJOR.MINOR.PATCH` (e.g., `1.0.0`)

- **MAJOR**: Breaking changes or major redesigns
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes

### Setting Version in Xcode UI

1. Open `Cloak.xcodeproj` in Xcode
2. Select the **Cloak** project in the navigator (top item)
3. Select the **Cloak** target
4. Go to the **General** tab
5. Under **Identity**, set:
   - **Version**: User-facing version (e.g., `1.0.0`)
   - **Build**: Build number (e.g., `1`, increment each release)

### Setting Version via Terminal

Edit `Cloak/Info.plist`:

```bash
# Set version to 1.0.0
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.0.0" Cloak/Info.plist

# Set build number to 1
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 1" Cloak/Info.plist
```

Or manually edit `Cloak/Info.plist`:

```xml
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
<key>CFBundleVersion</key>
<string>1</string>
```

---

## Building the App

### Using Xcode UI

1. **Open the project**
   ```bash
   open Cloak.xcodeproj
   ```

2. **Set build configuration to Release**
   - Menu: **Product** → **Scheme** → **Edit Scheme...**
   - Select **Run** on the left
   - Change **Build Configuration** to **Release**
   - Click **Close**

3. **Build the app**
   - Menu: **Product** → **Build** (or `Cmd+B`)

4. **Locate the built app**
   - Menu: **Product** → **Show Build Folder in Finder**
   - Navigate to `Build/Products/Release/Cloak.app`

5. **Alternative: Archive (recommended for distribution)**
   - Menu: **Product** → **Archive**
   - When complete, the Organizer window opens
   - Right-click the archive → **Show in Finder**
   - Right-click the `.xcarchive` → **Show Package Contents**
   - Navigate to `Products/Applications/Cloak.app`

### Using Terminal

```bash
cd /path/to/Cloak

# Clean previous builds
xcodebuild clean -project Cloak.xcodeproj -scheme Cloak -configuration Release

# Build release version
xcodebuild -project Cloak.xcodeproj \
  -scheme Cloak \
  -configuration Release \
  build \
  CONFIGURATION_BUILD_DIR=./build

# The app is now at ./build/Cloak.app
```

**One-liner:**
```bash
xcodebuild clean -project Cloak.xcodeproj -scheme Cloak -configuration Release && xcodebuild -project Cloak.xcodeproj -scheme Cloak -configuration Release build CONFIGURATION_BUILD_DIR=./build
```

---

## Creating a DMG

### Using Terminal (Recommended)

**Simple DMG:**
```bash
# Create DMG from the app
hdiutil create \
  -volname "Cloak" \
  -srcfolder ./build/Cloak.app \
  -ov \
  -format UDZO \
  Cloak-1.0.0.dmg
```

**DMG with Applications shortcut (prettier):**
```bash
# Create staging folder
mkdir -p dmg-staging
cp -R ./build/Cloak.app dmg-staging/
ln -s /Applications dmg-staging/Applications

# Create DMG
hdiutil create \
  -volname "Cloak" \
  -srcfolder dmg-staging \
  -ov \
  -format UDZO \
  Cloak-1.0.0.dmg

# Cleanup
rm -rf dmg-staging
```

### Using Disk Utility (GUI)

1. Open **Disk Utility** (Spotlight → "Disk Utility")
2. Menu: **File** → **New Image** → **Image from Folder...**
3. Select the folder containing `Cloak.app`
4. Set:
   - **Save As**: `Cloak-1.0.0`
   - **Format**: `compressed`
5. Click **Save**

---

## GitHub Releases

### Manual Release

1. **Build and create DMG** (see sections above)

2. **Create a git tag**
   ```bash
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```

3. **Create release on GitHub**
   - Go to your repo → **Releases** → **Draft a new release**
   - Choose the tag `v1.0.0`
   - Set title: `Cloak v1.0.0`
   - Add release notes
   - Upload files:
     - `Cloak-1.0.0.dmg`
     - `Cloak.app` (zip it first: `zip -r Cloak-1.0.0-app.zip build/Cloak.app`)
   - Click **Publish release**

### Automated Release (GitHub Actions)

This project includes a GitHub Actions workflow that automatically:
- Builds the app when you push a version tag
- Creates a DMG
- Creates a GitHub release with both `.app` (zipped) and `.dmg`

**To create an automated release:**

1. **Update the version** in `Cloak/Info.plist`

2. **Commit the changes**
   ```bash
   git add .
   git commit -m "Bump version to 1.0.0"
   ```

3. **Create and push a tag**
   ```bash
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin main
   git push origin v1.0.0
   ```

4. **Wait for the action to complete**
   - Go to **Actions** tab in your GitHub repo
   - The release will be created automatically

---

## Local Build Script

A convenience script is provided at `scripts/build-release.sh`:

```bash
# Build and create DMG for version 1.0.0
./scripts/build-release.sh 1.0.0

# Output:
#   dist/Cloak.app
#   dist/Cloak-1.0.0.dmg
#   dist/Cloak-1.0.0-app.zip
```

---

## Installation Instructions for Users

Include these instructions on your website/release page:

### Download and Install

1. Download `Cloak-X.X.X.dmg` from the [Releases page](../../releases)
2. Open the DMG file
3. Drag **Cloak** to **Applications**
4. Eject the DMG

### First Launch (Important!)

Since Cloak is not signed with an Apple Developer certificate, macOS will block it on first launch. To open it:

**Option 1: Right-click method (easiest)**
1. Open **Applications** folder
2. **Right-click** (or Control-click) on **Cloak**
3. Select **Open** from the menu
4. Click **Open** in the dialog that appears

You only need to do this once. After that, Cloak opens normally.

**Option 2: Terminal method**
```bash
xattr -cr /Applications/Cloak.app
```
Then open Cloak normally.

**Option 3: System Settings method**
1. Try to open Cloak (it will be blocked)
2. Open **System Settings** → **Privacy & Security**
3. Scroll down to find the message about Cloak being blocked
4. Click **Open Anyway**

---

## Troubleshooting

### Build fails with signing errors

Since we're not code signing, make sure the project is set to not require signing:

1. Open Xcode → Select project → **Signing & Capabilities**
2. Uncheck **Automatically manage signing**
3. Set **Signing Certificate** to **Sign to Run Locally** or leave blank

Or via terminal, the build command already handles this by not specifying a signing identity.

### "App is damaged" error

The app needs the quarantine attribute removed:
```bash
xattr -cr /Applications/Cloak.app
```

### App won't open after macOS update

Re-run the quarantine removal command above, or use the right-click → Open method.
