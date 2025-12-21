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

## Installation

### Requirements
- macOS 14.0 or later
- Screen Recording permission

### Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/Cloak.git
   cd Cloak
   ```

2. Open in Xcode:
   ```bash
   open Cloak.xcodeproj
   ```

3. Build and run (Cmd+R)

## Usage

### Quick Start

1. **Launch Cloak** - The app opens with a start screen
2. **Configure Privacy Mode** - Choose Blur, Image, or Black screen
3. **Click "Start Sharing"** - Cloak begins mirroring your screen
4. **Share in Video Call** - In Zoom/Meet/Teams, share the "Cloak" window (not your screen)
5. **Toggle Privacy** - Press `Cmd+Option+H` anytime to toggle privacy mode

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Option+H` | Toggle privacy mode (works globally) |
| `Cmd+F` | Toggle fullscreen |
| `Cmd+Q` | Quit Cloak |

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
