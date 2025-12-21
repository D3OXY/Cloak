# Cloak

Hide your screen during video calls while still being able to see and use your computer normally.

## What is Cloak?

Cloak is a macOS app that creates a shareable window for video calls. Instead of sharing your actual screen, you share the Cloak window. When you need privacy, toggle privacy mode and viewers see a placeholder while you continue working normally.

## Features

- **Privacy Toggle**: Instantly hide your screen with a global hotkey
- **Multiple Privacy Modes**: Choose between blur pattern, custom image, or black screen
- **Global Hotkey**: Works even when Cloak isn't the active app
- **Fullscreen Support**: Use Cloak in fullscreen for a cleaner look
- **Hover Controls**: Stop/Privacy buttons appear only when you hover over the window

## Download

Download the latest version from the [Releases page](../../releases).

### First Launch

Since Cloak is not signed with an Apple Developer certificate, macOS will block it on first launch:

1. Open **Applications** folder
2. **Right-click** on **Cloak** → Select **Open**
3. Click **Open** in the dialog

You only need to do this once.

Alternatively, run in Terminal:
```bash
xattr -cr /Applications/Cloak.app
```

## Installation

### Requirements
- macOS 14.0 or later
- Screen Recording permission

### Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/d3oxy/Cloak.git
   cd Cloak
   ```

2. Open in Xcode:
   ```bash
   open Cloak.xcodeproj
   ```

3. Build and run (Cmd+R)

See [DISTRIBUTION.md](DISTRIBUTION.md) for creating releases.

## Usage

### Quick Start

1. **Launch Cloak** - The app opens with a start screen
2. **Configure Privacy Mode** - Choose Blur, Image, or Black screen
3. **Set Your Hotkeys** - Configure keyboard shortcuts for quick access
4. **Click "Start Sharing"** - Cloak begins mirroring your screen
5. **Share in Video Call** - In Zoom/Meet/Teams, share the "Cloak" window (not your screen)
6. **Toggle Privacy** - Use your configured hotkey or hover controls

### Keyboard Shortcuts

Cloak has no default hotkeys - you configure your own! On the start screen, you'll see:

| Action | Description |
|--------|-------------|
| Toggle Privacy | Show/hide your screen |
| Start/Stop Sharing | Begin or end screen capture |
| Toggle Fullscreen | Enter/exit fullscreen mode |

**To set a hotkey:**
1. Click the "Click to set" button next to the action
2. Press your desired key combination (must include a modifier like Cmd, Option, Ctrl, or Shift)
3. The hotkey is saved and works globally (even when Cloak is in the background)

**To clear a hotkey:**
Click the "✕" button next to the hotkey.

All hotkeys persist between app restarts.

### Privacy Modes

- **Blur**: Shows a gray striped pattern
- **Image**: Shows a custom image you select
- **Black**: Shows a completely black screen

### Menu Bar

Click the eye icon in your menu bar to:
- See current privacy status
- Start/Stop sharing
- Toggle privacy
- Show the Cloak window
- Quit the app

## How It Works

1. Cloak captures your screen using macOS ScreenCaptureKit
2. The captured content is displayed in a separate window
3. You share this window in your video call instead of your actual screen
4. When privacy is toggled, viewers see the placeholder instead of your screen
5. Your actual screen remains visible to you at all times

## Permissions

Cloak requires **Screen Recording** permission to function:

1. Open System Settings
2. Go to Privacy & Security > Screen Recording
3. Enable Cloak
4. Restart the app if needed

## Troubleshooting

### Window not appearing in screen share options
- Make sure Cloak is running and the window is visible
- Try selecting "Window" instead of "Screen" in your video call app
- Restart the video call application

### Privacy toggle not working
- Ensure you've started sharing first (click "Start Sharing")
- Check that the global hotkey isn't conflicting with another app

### Screen not capturing
- Grant Screen Recording permission in System Settings
- Restart Cloak after granting permission

## License

MIT License - feel free to use and modify as needed.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
