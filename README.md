# HereTRMNL

macOS 26+ app that displays LaraPaper (TRMNL BYOS) screen content in a dedicated window.

## What it does

- Connects to a custom LaraPaper / TRMNL server as a **single independent device**
- Polls official `GET /api/display` with firmware headers `ID` + `Access-Token`
- Downloads and shows `image_url`, refreshing by `refresh_rate`
- Skips redraw when `filename` / `image_name` is unchanged

## Requirements

- macOS 26.0+
- Xcode 26+
- A LaraPaper (or compatible) device ID (MAC) and access token

## Build

```bash
xcodegen generate
open HereTRMNL.xcodeproj
```

Select the **HereTRMNL** scheme, then Run.

## Setup

1. Open **Settings** (⌘,)
2. Enter Base URL (e.g. `https://your-server.example`) — no `/api/display` suffix
3. Enter Device ID (MAC) and Access Token
4. **Save & Connect**

Manual refresh: toolbar button or ⌘R.
