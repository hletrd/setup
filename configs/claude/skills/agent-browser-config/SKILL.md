---
name: agent-browser-config
version: 1.0.0
description: |
  Browser configuration: viewport sizing, device emulation, geolocation,
  offline mode, color scheme, and HTTP settings.
allowed-tools:
  - Bash
---

# Agent Browser: Browser Configuration

Configure viewport, emulate devices, set geolocation, and control browser settings.

## Viewport

```sh
agent-browser set viewport <width> <height> [scale]  # Set viewport dimensions
```

## Device Emulation

```sh
agent-browser set device <name>    # Emulate a device (e.g., "iPhone 15", "Pixel 7")
```

Common device names: `iPhone 15`, `iPhone 15 Pro Max`, `iPad Pro`, `Pixel 7`,
`Galaxy S23`, `Desktop Chrome HiDPI`, etc.

## Geolocation

```sh
agent-browser set geo <lat> <lng>  # Set geolocation coordinates
```

## Offline Mode

```sh
agent-browser set offline on       # Enable offline mode
agent-browser set offline off      # Disable offline mode
```

## Color Scheme

```sh
agent-browser set media dark       # Emulate dark mode (prefers-color-scheme: dark)
agent-browser set media light      # Emulate light mode
```

## Examples

```sh
# Mobile testing
agent-browser set device "iPhone 15"
agent-browser open https://example.com
agent-browser screenshot /tmp/mobile.png

# Responsive testing with exact dimensions
agent-browser set viewport 1920 1080
agent-browser screenshot /tmp/desktop.png
agent-browser set viewport 768 1024
agent-browser screenshot /tmp/tablet.png
agent-browser set viewport 375 812
agent-browser screenshot /tmp/mobile.png

# Test geolocation features
agent-browser set geo 37.7749 -122.4194
agent-browser open https://maps.example.com

# Test offline behavior
agent-browser open https://example.com
agent-browser set offline on
agent-browser reload
agent-browser screenshot /tmp/offline.png

# Dark mode testing
agent-browser set media dark
agent-browser screenshot /tmp/dark-mode.png
```

## Guidelines

- Set viewport/device before navigating for accurate rendering
- Device emulation includes viewport, user agent, and device scale factor
- Geolocation requires the page to request location permissions
- Offline mode simulates network disconnection for PWA testing
- Use `set media` to test dark/light mode CSS without OS changes
