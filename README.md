# HereTRMNL

[![Release](https://img.shields.io/github/v/release/locusable-studio/HereTRMNL)](https://github.com/locusable-studio/HereTRMNL/releases/latest)
[![Release workflow](https://github.com/locusable-studio/HereTRMNL/actions/workflows/release.yml/badge.svg)](https://github.com/locusable-studio/HereTRMNL/actions/workflows/release.yml)
[![macOS](https://img.shields.io/badge/macOS-26%2B-black?logo=apple)](https://github.com/locusable-studio/HereTRMNL#download)
[![License](https://img.shields.io/github/license/locusable-studio/HereTRMNL)](https://github.com/locusable-studio/HereTRMNL/blob/main/LICENSE)

A macOS menu bar app that mirrors your [LaraPaper](https://github.com/usetrmnl) / TRMNL BYOS screen on the desktop. The display sits between the wallpaper and the desktop icons (click-through while an image is shown).

<p align="center">
  <img src="docs/screenshot.png" alt="HereTRMNL e-ink display between wallpaper and desktop icons" width="880">
</p>

## What it does

HereTRMNL turns this Mac into a LaraPaper display device:

- Lives in the menu bar (no Dock icon)
- Desktop-layer window: above the wallpaper, below Finder icons; clicks pass through when a screen is showing
- Fixed device-sized layout; pick screen and corner (or center) from the menu bar
- Polls the server display API, shows the current image, and refreshes on the server interval
- Skips redraw when the image has not changed
- Manual refresh and launch at login

## Download

- **[Latest DMG](https://github.com/locusable-studio/HereTRMNL/releases/latest/download/HereTRMNL.dmg)** from [GitHub Releases](https://github.com/locusable-studio/HereTRMNL/releases)
- Requires **macOS 26.0+** and a LaraPaper-compatible base URL, device ID, and access token

## Setup

1. Open **Connection Settings…** from the menu bar item (or ⌘,)
2. Enter the base URL (e.g. `https://your-server.example`) — without `/api/display`
3. Enter Device ID and Access Token
4. **Connect** (or **Verify and Save** when editing)

Manual refresh: menu bar **Refresh Now** or ⌘R. Placement: menu bar **Screen** / **Position**. Quit from the menu bar item.

## Build

1. Open `HereTRMNL.xcodeproj` in **Xcode 26+**
2. Select the **HereTRMNL** scheme
3. Build and run

## License

MIT License — see [LICENSE](LICENSE).
