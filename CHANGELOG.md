# Changelog

All notable changes to Cloak will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
| 1.1.0 | 2024-12-21 | App exclusion, self-hiding window, documentation |
| 1.0.0 | 2024-12-21 | Initial release with privacy toggle, hotkeys, fullscreen |
