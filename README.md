# KeyLight

<p align="center"><img src="docs/mascot.png" width="160" alt="KeyLight mascot, from the Menubarn widget library"></p>

A tiny standalone macOS menu-bar app that remaps **Ctrl + the brightness keys**
to **keyboard-backlight** up/down — a drop-in replacement for using
BetterTouchTool just for that. The menu-bar icon shows the current backlight
level, and a small preferences window lets you rebind the two controls.

Built on [StatusItemKit](https://github.com/nicholaspsmith/StatusItemKit) (the
menu-bar shell) and [HotkeyKit](https://github.com/nicholaspsmith/HotkeyKit)
(the global key-tap engine).

## What it does

| Trigger (default) | Action |
|-------------------|--------|
| `Ctrl + Brightness Up` | keyboard backlight up one step (1/16) |
| `Ctrl + Brightness Down` | keyboard backlight down one step |

The original brightness key is swallowed, so the display brightness doesn't
change. The menu-bar gauge tracks the level; rebind either control in
Preferences.

Pick the meter you prefer under **menu ▸ Icon** — Gauge, Arc, Pie or Wedge. Each
row previews itself, and the choice persists across launches.

## How it works

- **HotkeyKit** owns a `CGEventTap` that intercepts the brightness media keys,
  matches them against the bindings, and swallows the matched event.
- **CoreBrightness** (`KeyboardBrightnessClient`, private framework) reads/sets
  the built-in keyboard backlight. The keyboard id is discovered via
  `copyKeyboardBacklightIDs` (never hardcoded). When the backlight is suppressed
  (clamshell / lid closed), sets no-op — the app handles this gracefully.

## Install

```sh
./install.sh
```

Builds `KeyLight.app`, symlinks it into `~/Applications`, and launches it. Grant
**Accessibility** when prompted (needed to intercept the keys). Enable
**Start at Login** from the menu if you want it persistent.

### Make the Accessibility grant survive rebuilds (recommended)

By default the app is ad-hoc signed, so every rebuild changes its code hash and
macOS invalidates the Accessibility grant — you'd have to re-approve KeyLight
after each rebuild. Create a stable local signing identity **once**:

```sh
../StatusItemKit/scripts/setup-signing.sh   # one-time, idempotent
./install.sh                                # rebuild now signs with it
```

Grant Accessibility one more time after that; every later rebuild keeps it.

**If the keys stop working after a rebuild** (i.e. still ad-hoc signed), the grant
went stale — re-approve KeyLight in System Settings ▸ Privacy & Security ▸
Accessibility. If it's already toggled on but inert, clear the stale entry and
re-grant:

```sh
tccutil reset Accessibility com.nicholaspsmith.KeyLight
open ~/Applications/KeyLight.app
```

## Develop

```sh
swift build           # compile
swift test            # KeyLightCore unit tests (level math, binding persistence)
swift run KeyLight     # run from the terminal (grant Accessibility to the binary)
```

Requires sibling checkouts of `StatusItemKit` and `HotkeyKit` next to this repo.

## Requirements

- macOS 13+ (Apple Silicon validated on macOS 26 / Tahoe)
- Accessibility permission

## Replacing BetterTouchTool

Once KeyLight works, confirm BTT isn't doing anything else for you, then remove
its brightness triggers (or quit BTT) and uninstall it.

## Why not a SwiftBar plugin?

This is a standalone `.app` built on [StatusItemKit](https://github.com/nicholaspsmith/StatusItemKit), not a script under a plugin host: no SwiftBar to install, a real AppKit menu instead of rendered stdout, event-driven updates instead of a re-run timer, and an icon that keeps its place in the bar. Intercepting the brightness keys needs a `CGEventTap`, which a plugin script cannot own at all. The full comparison is in [StatusItemKit's README](https://github.com/nicholaspsmith/StatusItemKit#why-not-swiftbar).

## The menu-bar suite

Part of a suite of macOS menu-bar apps that share one framework, one
build-and-sign script, and one installer. They are designed to sit in the
same bar together: consistent menus, a common **Icon** picker for shape and
colour, and cooperative hiding so no icon strands another.

| App | What it does |
|---|---|
| [Claude Usage](https://github.com/nicholaspsmith/claude-usage-menubar) | Claude Code plan limits, resets, and live agent sessions |
| [Apollo Monitor](https://github.com/nicholaspsmith/apollo-monitor-menubar) | Universal Audio Apollo monitor level, plus a UA process watchdog |
| [Battery Time](https://github.com/nicholaspsmith/battery-time-menubar) | Time remaining, power mode, and 24h usage |
| [VPN & DNS](https://github.com/nicholaspsmith/vpn-dns-menubar) | One dot for Mullvad + Tailscale state, with a DNS watcher |
| [Process Monitor](https://github.com/nicholaspsmith/MacOS_Process_Monitor) | Process-count sparkline against the per-UID limit |
| **KeyLight** | Ctrl+brightness keys remapped to keyboard backlight |
| [MacRecorder](https://github.com/nicholaspsmith/MacRecorder) | Screen recording with system audio |
| [Media Tracking Killer](https://github.com/nicholaspsmith/media-tracking-killer-menubar) | Kills Apple's media tracking daemons |
| [Download Recycler](https://github.com/nicholaspsmith/download-recycler-menubar) | Sweeps stale files out of ~/Downloads |
| [Curtain](https://github.com/nicholaspsmith/menubar-curtain) | Hides a block of status icons by width, so it cannot strand one |

| Framework | |
|---|---|
| [StatusItemKit](https://github.com/nicholaspsmith/StatusItemKit) | Status-item lifecycle, polling, menus, meter icons, the shared Icon picker |
| [HotkeyKit](https://github.com/nicholaspsmith/HotkeyKit) | CGEventTap engine for intercepting and remapping global keys |

Install the whole suite on a fresh Mac with
[macOS Dev Environment Setup](https://github.com/nicholaspsmith/MacOS-Dev-Environment-Setup):

```bash
git clone https://github.com/nicholaspsmith/MacOS-Dev-Environment-Setup.git
cd MacOS-Dev-Environment-Setup && ./bootstrap.sh --all
```
