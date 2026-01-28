![Cloak Banner](/assets/banner.jpeg)

# Cloak

Hide your screen during screen sharing while still being able to see and use your computer normally.

## What is Cloak?

Cloak is a macOS app that creates a shareable window for screen sharing. Instead of sharing your actual screen, you share the Cloak window. When you need privacy, toggle privacy mode and viewers see a placeholder while you continue working normally.

## Features

- **Privacy Toggle**: Instantly hide your screen with a global hotkey
- **Multiple Privacy Modes**: Choose between blur pattern, custom image, or black screen
- **Global Hotkeys**: Work even when Cloak isn't the active app
- **Fullscreen Support**: Use Cloak in fullscreen for a cleaner look
- **Hover Controls**: Stop/Privacy buttons appear only when you hover over the window
- **Self-Hiding**: Cloak window and controls are automatically hidden from the capture
- **App Exclusion**: Hide specific apps from the shared screen (e.g., Slack, 1Password)

## Download

Download the latest version from the [Releases page](../../releases).

### First Launch

Since Cloak is not signed with an Apple Developer certificate, macOS will block it on first launch. Choose one of the following methods:

**Method 1: Terminal (Recommended)**

Run this command in Terminal **before** opening Cloak:

```bash
xattr -cr /Applications/Cloak.app
```

Open Cloak normally.

OR

If you see a dialog saying the app is "damaged and can't be opened":

**Important:** Click **"Cancel"** (not "Move to Trash") when you see this dialog. Then run the Terminal command above and open Cloak normally.

**Method 2: System Settings**

1. Try to open Cloak (it will show "App is damaged and can't be opened")
   ![Damaged App Dialog](/assets/damaged-app-dialog.png)
2. Click **"Cancel"** (not "Move to Trash")
3. Go to **System Settings** → **Privacy & Security**
4. Scroll down to find **Cloak** and click **"Open Anyway"**
5. Authenticate as an administrator
6. Cloak will now open

You only need to do this once after downloading.
