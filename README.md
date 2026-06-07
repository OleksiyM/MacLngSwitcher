# MacLngSwitcher

`MacLngSwitcher` is a lightweight macOS menu bar utility designed for fast and seamless keyboard layout switching using modifier keys:
- **Left Control** — Tap once to switch to the English (U.S./ABC) layout.
- **Right Control** — Tap once to cycle between your other selected keyboard layouts (e.g., Russian, Ukrainian).
- **Modifier Combination Safety** — Normal shortcuts (like `Ctrl+C`, `Ctrl+V`, or holding Control down) are preserved and will not trigger a layout switch.

The utility features a premium, native macOS settings window designed to blend perfectly with system windows, featuring real-time system vibrancy (Vibrancy Popover material), support for Dark/Light themes, and system accent colors.

## Features

- **Double-Control Map**: Left Control for a fixed default layout (English), Right Control to cycle through multiple layouts.
- **Custom Sensitivity**: Slider to adjust the tap timeout sensitivity (between 0.15s and 0.60s).
- **Auto-Start**: Modern `SMAppService` API integration to launch automatically at macOS boot.
- **Vibrancy Design**: High-fidelity, flat native UI with zero CPU overhead in idle state.
- **Self-Contained Build**: Built completely via command line without heavy Xcode workspace overhead.

## Requirements

- macOS 13.0 (Ventura) or newer.
- **Accessibility Access** is required for the application to monitor global modifier keys.

---

## How to Build

You do not need Xcode GUI to build this application. A lightweight compilation script using `swiftc` is provided.

1. **Clone the repository**:
   ```bash
   git clone https://github.com/<your-username>/MacLngSwitcher.git
   cd MacLngSwitcher
   ```

2. **Make the build script executable**:
   ```bash
   chmod +x build.sh
   ```

3. **Build the application**:
   ```bash
   ./build.sh
   ```
   This will:
   - Generate `AppIcon.icns` from CoreGraphics script.
   - Compile all Swift sources.
   - Output a native macOS bundle named `MacLngSwitcher.app` in the root folder.

---

## How to Install and Run

1. **Copy the application to your Applications folder**:
   ```bash
   rm -rf /Applications/MacLngSwitcher.app
   cp -R MacLngSwitcher.app /Applications/
   ```
2. **Open the application**:
   ```bash
   open /Applications/MacLngSwitcher.app
   ```
3. **Grant Accessibility Permissions**:
   - The application will request Accessibility access on first launch.
   - Go to **System Settings > Privacy & Security > Accessibility** and enable `MacLngSwitcher`.
   - Click **Restart Application** in the settings window to apply permissions.
