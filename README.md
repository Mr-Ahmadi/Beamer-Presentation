# Beamer

Beamer is a two-app presentation system:
- **BeamerPresenter (macOS):** loads and presents PDF slides.
- **BeamerRemote (iOS):** controls slides wirelessly from phone.

Both apps communicate over local network using `MultipeerConnectivity` (`_beamer-ctrl._tcp`).

## Features

- PDF-based presentation flow
- Smooth slide navigation and transitions (`None`, `Fade`, `Push`, `Scale`)
- Fullscreen presentation mode with overlay controls
- Next-slide preview in presenter sidebar
- Blackout mode during presentation
- Phone remote with:
  - Previous/next and +/-5 jumps
  - First/last slide navigation
  - Slide jump slider/stepper
  - Fullscreen and blackout toggles
- Multi-display support on presenter (auto/external/selected screen)

## Project Structure

- `BeamerPresenter/` macOS app target and source
- `BeamerRemote/` iOS app target and source

## Requirements

- Xcode 15+
- macOS 14.4+ for presenter
- iOS 17.5+ for remote
- Both devices on same local network (or nearby peer connectivity conditions)

## Running

1. Open `BeamerPresenter/BeamerPresenter.xcodeproj` and run `BeamerPresenter` on Mac.
2. Open `BeamerRemote/BeamerRemote.xcodeproj` and run `BeamerRemote` on iPhone.
3. In remote app, tap **Connect** and choose the presenter Mac.
4. On presenter, open a PDF and start presenting.

## Notes

- Shared schemes include `IDEPreferLogStreaming=YES` for improved run-log behavior.
- App icons are now visually consistent across both apps with shared Beamer branding.
