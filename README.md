# Net Monitor

A tiny macOS menu bar app that shows live network speed, similar to NetMonitor+.

```
↑ 120 KB/s
↓ 3.4 MB/s
```

## Features

- Live upload and download speed in the menu bar, updated every second
- Dropdown with current speeds and data used this session
- Rolling 60-second graph (download in blue, upload in orange) that scales to the recent peak
- No Dock icon; runs as a menu bar accessory

Traffic is summed across all active, non-loopback network interfaces, so a VPN or other virtual interface may be counted as well.

## Requirements

- macOS
- Xcode command line tools (`swiftc`)

## Build and run

```sh
./build.sh
open NetMonitor.app
```

To start at login, move `NetMonitor.app` to Applications, open it, and tick **Launch at Login** in its menu
(it appears under System Settings → General → Login Items).

The app is only ad-hoc signed. If you copy it to another Mac, Gatekeeper may ask you to approve it.

## App icon

The icon is drawn in code by `tools/make_icon.swift`; the generated files live in `assets/` and the iOS asset catalog.

### Icon Composer layers

`swiftc tools/make_icon.swift -o /tmp/make_icon && /tmp/make_icon ios.png mac.png assets/layers` also writes
`assets/layers/{background,rabbit,speed_lines}.png` (1024 px). In Icon Composer, add `background.png` as the
background and `speed_lines.png` and `rabbit.png` as foreground layers (rabbit on top). Set the speed-lines layer
to about 60% opacity. Save the `.icon` into the Xcode project to replace the flat PNG.

## Project layout

- `main.swift` — the whole app (traffic sampling, status item, menu, graph view)
- `assets/` — app icon (`AppIcon.icns` for macOS, 1024 px PNGs)
- `tools/make_icon.swift` — icon generator
- `ios/` — iPhone app
- `build.sh` — compiles and packages `NetMonitor.app`

## iOS version

`ios/` contains a SwiftUI iPhone app (iOS 17+) with live download/upload speed, a 60-second chart,
a Wi-Fi vs cellular split, and session totals. iOS has no menu bar and suspends apps in the
background, so speeds update only while the app is open (it can keep the screen awake).

```sh
brew install xcodegen
cd ios && xcodegen generate && open NetMonitor.xcodeproj
```

Pick your team under Signing & Capabilities to run on a device.
