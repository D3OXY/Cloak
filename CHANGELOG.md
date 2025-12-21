# Changelog

All notable changes to Cloak will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
| 1.3.3 | 2024-12-21 | HUD above fullscreen, green menu icon, faster hotkeys |
| 1.3.2 | 2024-12-21 | Dynamic aspect ratio, smart visibility (hidden until sharing) |
| 1.3.1 | 2024-12-21 | Fix window sharing visibility, self-hide toggle |
| 1.3.0 | 2024-12-21 | Live settings panel, conditional UI, modernized design |
| 1.2.0 | 2024-12-21 | Real-time blur, blur intensity slider, liquid glass HUD |
| 1.1.0 | 2024-12-21 | App exclusion, self-hiding window, documentation |
| 1.0.0 | 2024-12-21 | Initial release with privacy toggle, hotkeys, fullscreen |
