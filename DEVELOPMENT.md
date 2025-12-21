# Development Guide

This guide is for developers (including AI assistants) working on Cloak.

## Project Overview

Cloak is a macOS privacy app that creates a shareable window for video calls. Instead of sharing your actual screen, you share the Cloak window, which can display a privacy overlay when needed.

### Tech Stack
- **Language**: Swift
- **Framework**: AppKit (NOT SwiftUI)
- **Screen Capture**: ScreenCaptureKit
- **Global Hotkeys**: Carbon.HIToolbox
- **Minimum macOS**: 14.0

### Key Files

| File | Purpose |
|------|---------|
| `Cloak/AppDelegate.swift` | Main application code (~1200 lines, contains all classes) |
| `Cloak/main.swift` | App entry point (manual NSApplication setup) |
| `Cloak/Info.plist` | App configuration and permissions |
| `Cloak.xcodeproj/project.pbxproj` | Xcode project settings |

### Architecture

All code is in `AppDelegate.swift` for simplicity:

```
AppDelegate.swift
├── AppDelegate (main app controller)
├── HotkeyManager (global hotkey registration)
├── HotkeyAction (enum for hotkey actions)
├── HotkeyConfig (hotkey configuration struct)
├── MainView (main window content)
├── StartScreenView (settings UI before capture)
├── PreviewView (displays captured screen)
├── ScreenCaptureEngine (handles screen capture)
├── PrivacyMode (enum: blur, image, black)
└── HUDWindow (floating notification window)
```

---

## Before Making Changes

### 1. Read the Existing Code

Always read `AppDelegate.swift` before making changes:
```bash
# Read the full file to understand the current implementation
cat Cloak/AppDelegate.swift
```

### 2. Understand the Build System

This is an Xcode project, NOT Swift Package Manager:
```bash
# Build the project
xcodebuild -project Cloak.xcodeproj -scheme Cloak -configuration Debug build

# Clean build (use when having issues)
xcodebuild clean -project Cloak.xcodeproj -scheme Cloak
rm -rf ~/Library/Developer/Xcode/DerivedData/Cloak-*
```

### 3. Check Current State

```bash
# Check git status
git status

# Check if there are uncommitted changes
git diff

# Check recent commits for context
git log --oneline -10
```

---

## Making Changes

### Code Style

1. **All code goes in AppDelegate.swift** - This is a small app, no need to split files
2. **Use AppKit, not SwiftUI** - The app uses NSWindow, NSView, etc.
3. **Mark sections with `// MARK: -`** for organization
4. **Use UserDefaults for persistence** - Simple key-value storage

### Common Patterns

**Adding a new setting:**
1. Add property to relevant class (usually `StartScreenView`)
2. Add UI in `setupUI()` method
3. Add load logic in `loadSettings()`
4. Add save logic (usually via UserDefaults)
5. Use the setting where needed

**Adding a new hotkey action:**
1. Add case to `HotkeyAction` enum
2. Update `displayName` and `storageKey` computed properties
3. Handle the action in `AppDelegate.hotkeyDidTrigger()`

**Modifying screen capture:**
1. Changes go in `ScreenCaptureEngine` class
2. `setupStream()` configures what gets captured
3. `SCContentFilter` controls what's included/excluded

### Testing Changes

```bash
# Quick build test
xcodebuild -project Cloak.xcodeproj -scheme Cloak -configuration Debug build CONFIGURATION_BUILD_DIR=./build-test 2>&1 | grep -E "(error:|warning:|BUILD)"

# Run the app
open ./build-test/Cloak.app

# Or build and run in one command
xcodebuild -project Cloak.xcodeproj -scheme Cloak -configuration Debug build CONFIGURATION_BUILD_DIR=./build-test && open ./build-test/Cloak.app
```

---

## After Making Changes

### 1. Test the Build

```bash
# Ensure it compiles
xcodebuild -project Cloak.xcodeproj -scheme Cloak -configuration Debug build CONFIGURATION_BUILD_DIR=./build-test 2>&1 | grep -E "(error:|BUILD)"
```

### 2. Test the App

- Launch the app and verify your changes work
- Test edge cases (what happens if user does X?)
- Test persistence (quit and relaunch, are settings saved?)

### 3. Update Documentation

If you added features, update:
- `README.md` - User-facing documentation
- `CHANGELOG.md` - Add entry under `[Unreleased]`
- `DISTRIBUTION.md` - If build/release process changed

### 4. Commit Changes

```bash
# Check what changed
git status
git diff

# Stage and commit with descriptive message
git add .
git commit -m "Add feature X

- Detail 1
- Detail 2

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <assistant_name> <noreply@anthropic.com>"
```

---

## Common Issues & Solutions

### Build Fails with Signing Errors

The app is not code-signed. If you see signing errors:
```bash
# Build without signing
xcodebuild ... CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

### "Hello World" or Old Code Showing

Xcode cached old build. Clean DerivedData:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/Cloak-*
xcodebuild clean -project Cloak.xcodeproj -scheme Cloak
```

### App Not Appearing in Screen Share Options

The window needs to be visible and on-screen. Make sure:
- Window is not minimized
- Window is on the current desktop/space

### Hotkeys Not Working Globally

Global hotkeys use Carbon APIs which require:
- The app to be running
- Hotkeys registered via `RegisterEventHotKey`
- Event handler installed via `InstallEventHandler`

### Screen Capture Permission

If capture isn't working:
1. Check System Settings > Privacy & Security > Screen Recording
2. Ensure Cloak is listed and enabled
3. Restart the app after granting permission

---

## Release Process

See `DISTRIBUTION.md` for full details. Quick summary:

### Local Build
```bash
./scripts/build-release.sh 1.0.0
# Creates dist/Cloak-1.0.0.dmg
```

### GitHub Release
```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin main
git push origin v1.0.0
# GitHub Actions creates the release automatically
```

---

## Project Structure

```
Cloak/
├── .github/
│   └── workflows/
│       └── release.yml      # GitHub Actions for automated releases
├── Cloak/
│   ├── AppDelegate.swift    # All application code
│   ├── main.swift           # App entry point
│   └── Info.plist           # App configuration
├── Cloak.xcodeproj/         # Xcode project
├── scripts/
│   └── build-release.sh     # Local release build script
├── CHANGELOG.md             # Version history
├── DEVELOPMENT.md           # This file
├── DISTRIBUTION.md          # Build and release guide
├── LICENSE                  # MIT License
└── README.md                # User documentation
```

---

## Tips for AI Assistants

1. **Always read before writing** - Read the relevant code section before making edits
2. **Test builds frequently** - Run xcodebuild after changes to catch errors early
3. **Use the todo list** - Track multi-step tasks with TodoWrite
4. **Commit incrementally** - Make focused commits after each feature/fix
5. **Update CHANGELOG.md** - Add entries for user-visible changes
6. **The user is a TypeScript dev** - Explain Swift/macOS concepts when relevant
