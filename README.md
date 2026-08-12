# HereTRMNL

A macOS menu bar app that mirrors your [LaraPaper](https://github.com/usetrmnl) / TRMNL BYOS screen on the desktop.

<p align="center">
  <img src="docs/screenshot.png" alt="HereTRMNL showing a LaraPaper e-ink screen over the desktop" width="880">
</p>

## Features

- Lives in the menu bar (no Dock icon)
- Polls `GET /api/display` with firmware-style `ID` and `Access-Token` headers
- Shows `image_url` and refreshes on `refresh_rate`
- Skips redraw when `filename` / `image_name` is unchanged
- Keep on top, restore device size, window opacity, launch at login
- Display tone (light / dark / automatic) for e-ink letterboxing

## Requirements

- macOS 26.0+
- Xcode 26+
- A LaraPaper-compatible base URL, device ID (MAC), and access token

## Build

```bash
open HereTRMNL.xcodeproj
```

Select the **HereTRMNL** scheme and Run.

## Setup

1. Open **Settings** from the menu bar item (or ⌘,)
2. Enter the base URL (e.g. `https://your-server.example`) — without `/api/display`
3. Enter Device ID and Access Token
4. **Save & Connect**

Manual refresh: toolbar button or ⌘R. Quit from the menu bar item or **Options → Quit HereTRMNL**.
