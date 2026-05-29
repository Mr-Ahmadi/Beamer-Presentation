# Beamer

Wireless presentation system with macOS presenter and iOS remote companion apps.

**BeamerPresenter** loads and presents PDF slides with speaker notes.  
**BeamerRemote** controls slides wirelessly over your local network via `MultipeerConnectivity`.

## Features

- PDF presentation with transitions (Fade, Push, Scale)
- TeX notes (`\note{...}`) parsing with live sync
- Fullscreen mode with overlay controls
- Next-slide preview and notes panel
- Remote: prev/next, ±5 jumps, first/last, jump slider, fullscreen & blackout toggles, notes
- Multi-display support (auto/external/manual selection)
- Blackout mode

## Requirements

| Platform | Version |
|---|---|
| Xcode | 15+ |
| macOS | 14.4+ |
| iOS | 17.5+ |

## Quick Start

1. Open `BeamerPresenter/BeamerPresenter.xcodeproj` → run on Mac.
2. Open `BeamerRemote/BeamerRemote.xcodeproj` → run on iPhone.
3. Tap **Connect** in the remote app and select your Mac.
4. On the presenter, open a PDF and start presenting.
