# Changelog

All notable changes to Cloak will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.0] - 2024-12-22

### Added
- **App icon**: Custom app icon with cloak/privacy theme
- **PiP persistence**: Window position and size saved between restarts
- **App icon guide**: `APP_ICON_GUIDE.md` with instructions for creating icons

### Fixed
- **HUD colors**: Privacy ON now shows green, Privacy OFF shows red
- **App hiding**: Changed to `onScreenWindowsOnly: false` to detect newly created windows

## [1.4.3] - 2024-12-22

### Fixed
- **HUD/PiP above fullscreen apps**: Now uses NSPanel with proper floating configuration
  - `isFloatingPanel = true`, `hidesOnDeactivate = false`
  - Maximum window level via `CGWindowLevelForKey(.maximumWindow)`
  - Proper `.fullScreenAuxiliary` collection behavior
- **App hiding on first launch**: Burst refresh pattern for instant detection
  - Refreshes at 0ms, 100ms, 200ms, 400ms, 700ms, 1000ms, 1500ms after launch
  - No debouncing - catches window as soon as it appears

## [1.4.2] - 2024-12-22

### Fixed
- **HUD/PiP above fullscreen apps**: Window level improvements (superseded by 1.4.3)

## [1.4.1] - 2024-12-22

### Fixed
- **HUD layout**: Improved alignment with vertically centered preview and icon+label group

### Changed
- HUD icon now appears above centered label text for cleaner look

## [1.4.0] - 2024-12-22

### Added
- **Picture-in-Picture (PiP) window**: Floating preview window to see what's being shared
  - Resizable and freely moveable
  - Hidden from screen capture (only you can see it)
  - Shows live preview including privacy mode effects
- **Toggle PiP hotkey**: New configurable hotkey to show/hide PiP window
- **HUD preview thumbnail**: Privacy toggle HUD now shows a small preview of what viewers see

### Changed
- **HUD duration**: Privacy toggle HUD now displays for 2 seconds (was 1.5 seconds)
- **Larger HUD**: HUD resized to accommodate preview thumbnail (220x100)

### Technical
- Added `PiPWindow` class with NSWindow styling for floating, resizable preview
- Extended `ScreenCaptureEngineDelegate` with `didReceiveFrame` for real-time PiP updates
- PiP window automatically excluded from self-capture when self-hiding is enabled

## [1.3.4] - 2024-12-21

### Changed
- **Instant app hiding**: Excluded apps now hide instantly when launched (was 2-second delay)
- **Event-driven detection**: Replaced 2-second polling timer with NSWorkspace notifications
- **Zero idle CPU**: No more background polling - only updates when apps actually launch/activate

### Performance
- Removed continuous 2-second timer (saves CPU when idle)
- Uses system notifications for immediate response (~300ms after app launch)
- More efficient than polling - only runs when needed

## [1.3.3] - 2024-12-21

### Fixed
- **HUD above fullscreen**: Privacy HUD now displays on top of fullscreen apps
- **Faster hotkey response**: Optimized toggle performance, especially from fullscreen apps

### Changed
- **Green menu bar icon**: Status bar icon now turns bright green when privacy is ON
- **HUD window level**: Uses screenSaver level to ensure visibility above all apps

## [1.3.2] - 2024-12-21

### Changed
- **Dynamic aspect ratio**: Window now matches your screen's aspect ratio for optimal preview quality
- **Locked aspect ratio**: Window maintains screen proportions when resizing
- **Smart visibility**: Window is hidden from external screen capture until sharing starts
  - Settings screen won't appear in Google Meet/Zoom
  - Only the preview becomes visible after clicking "Start Sharing"

## [1.3.1] - 2024-12-21

### Fixed
- **Window visible in screen share**: Cloak window is now visible when shared in Google Meet/Zoom (previously was completely hidden)
- **Self-hiding toggle**: Added option to hide/show Cloak window from its own preview (on by default)
- **Live blur intensity**: Blur slider now updates in real-time while sharing

### Changed
- Self-hiding now uses SCContentFilter exclusion instead of sharingType (only hides from own capture, not external apps)

## [1.3.0] - 2024-12-21

### Added
- **Live settings panel**: Change privacy mode, blur intensity, and image while sharing
- **Settings button**: New "Settings" button in hover controls during capture
- **Scrollable settings**: Start screen content now scrolls to fit any window size

### Changed
- **Conditional settings UI**: Only shows relevant options for selected privacy mode (blur slider for Blur, image chooser for Image)
- **Modernized UI**: Card-based layout with liquid glass effect backgrounds
- **Cleaner controls**: Vibrancy-styled hover controls bar
- **Compact design**: Streamlined settings with better spacing and typography

### Fixed
- **Content overflow**: Settings no longer clip or overflow on smaller windows

## [1.2.0] - 2024-12-21

### Added
- **Real-time blur**: Privacy blur now shows live blurred preview instead of static image
- **Blur intensity slider**: Adjustable blur intensity from 5 to 100
- **Liquid glass HUD**: Updated HUD design with macOS native vibrancy effect

### Changed
- **HUD position**: Moved from top center to bottom center of screen
- **Window hiding**: Cloak window and HUD now use `sharingType = .none` for reliable hiding

### Fixed
- **HUD visibility**: HUD no longer appears in screen capture
- **App exclusion refresh**: Excluded apps now stay hidden even after being reopened (2-second auto-refresh)

## [1.1.0] - 2024-12-21

### Added
- **Window exclusion**: Cloak window and HUD are now automatically hidden from the screen capture
- **App exclusion**: Users can specify apps by name to hide from the captured screen (e.g., hide Slack, 1Password)
- Multiple apps can be excluded simultaneously
- Excluded apps list persists between restarts
- **CHANGELOG.md**: Version history documentation
- **DEVELOPMENT.md**: Developer guide for contributing

## [1.0.0] - 2024-12-21

### Added
- Initial release
- **Privacy Toggle**: Instantly hide your screen with customizable global hotkeys
- **Multiple Privacy Modes**: Choose between blur pattern, custom image, or black screen
- **Customizable Hotkeys**: Configure your own keyboard shortcuts for:
  - Toggle Privacy (show/hide screen)
  - Start/Stop Sharing
  - Toggle Fullscreen
- **Global Hotkeys**: Work even when Cloak isn't the active app (uses Carbon.HIToolbox)
- **Fullscreen Support**: Transparent title bar with fullscreen button in hover controls
- **Hover Controls**: Stop, Privacy, and Fullscreen buttons appear only when hovering over the window
- **Menu Bar Icon**: Quick access to all controls from the system menu bar
- **Screen Capture**: Uses macOS ScreenCaptureKit for efficient screen mirroring
- **Persistence**: All settings (privacy mode, custom image, hotkeys) saved between restarts

### Technical
- Built with AppKit (not SwiftUI) for better window management
- Uses `NSWindow` with `fullSizeContentView` style for transparent title bar
- Uses `NSTrackingArea` for hover detection
- Uses `Carbon.HIToolbox` for global hotkey registration
- Uses `UserDefaults` for persistence
- Deployment target: macOS 14.0+

---

## Version History Summary

| Version | Date | Highlights |
|---------|------|------------|
| 1.5.0 | 2024-12-22 | App icon, PiP persistence, HUD color fix |
| 1.4.3 | 2024-12-22 | NSPanel for HUD/PiP, burst refresh for app hiding |
| 1.4.2 | 2024-12-22 | Window level improvements |
| 1.4.1 | 2024-12-22 | Improved HUD layout |
| 1.4.0 | 2024-12-22 | Picture-in-Picture preview, PiP hotkey, HUD preview thumbnail |
| 1.3.4 | 2024-12-21 | Instant app hiding, event-driven detection, zero idle CPU |
| 1.3.3 | 2024-12-21 | HUD above fullscreen, green menu icon, faster hotkeys |
| 1.3.2 | 2024-12-21 | Dynamic aspect ratio, smart visibility (hidden until sharing) |
| 1.3.1 | 2024-12-21 | Fix window sharing visibility, self-hide toggle |
| 1.3.0 | 2024-12-21 | Live settings panel, conditional UI, modernized design |
| 1.2.0 | 2024-12-21 | Real-time blur, blur intensity slider, liquid glass HUD |
| 1.1.0 | 2024-12-21 | App exclusion, self-hiding window, documentation |
| 1.0.0 | 2024-12-21 | Initial release with privacy toggle, hotkeys, fullscreen |
