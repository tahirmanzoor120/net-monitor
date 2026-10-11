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

To start at login, move `NetMonitor.app` to Applications and add it under
System Settings → General → Login Items.

The app is only ad-hoc signed. If you copy it to another Mac, Gatekeeper may ask you to approve it.

## Project layout

- `main.swift` — the whole app (traffic sampling, status item, menu, graph view)
- `build.sh` — compiles and packages `NetMonitor.app`
