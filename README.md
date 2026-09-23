# KeyLight

<p align="center"><img src="docs/mascot.png" width="160" alt="KeyLight mascot, from the Menubarn widget library"></p>

A tiny standalone macOS menu-bar app that remaps **Ctrl + the brightness keys**
to **keyboard-backlight** up/down — a drop-in replacement for using
BetterTouchTool just for that — and gives **third-party keyboards** the
brightness and volume keys an Apple keyboard has on F1/F2 and F10–F12. The
menu-bar icon shows the current backlight level, and a small preferences window
lets you rebind the two backlight controls.

Built on [StatusItemKit](https://github.com/nicholaspsmith/StatusItemKit) (the
menu-bar shell) and [HotkeyKit](https://github.com/nicholaspsmith/HotkeyKit)
(the global key-tap engine). Part of the
[Menubarn](https://widgets.nicksmith.software) widget library.

## What it does

| Trigger (default) | Action |
|-------------------|--------|
| `Ctrl + Brightness Up` | keyboard backlight up one step (1/16) |
| `Ctrl + Brightness Down` | keyboard backlight down one step |
| `Ctrl + F2` / `Ctrl + F1` | the same, for keyboards whose F1/F2 are plain F-keys |

The original brightness key is swallowed, so the display brightness doesn't
change. The menu-bar gauge tracks the level; rebind either control in
Preferences. The menu's first row is a brightness slider, so the backlight can
also be set by dragging.

### Third-party keyboards

An Apple keyboard's F1/F2 and F10–F12 send brightness and volume as media
keys. A generic Bluetooth or USB board sends them as plain F1–F12, so macOS
does nothing with them (or worse: F11 hides every window). With **menu ▸
Function Keys on Other Keyboards** on (the default), KeyLight sends the media
key an Apple keyboard would have sent:

| Key on a non-Apple keyboard | Becomes |
|-----------------------------|---------|
| `F1` / `F2` | brightness down / up |
| `F10` | mute |
| `F11` / `F12` | volume down / up |

Holding a key repeats. The remap posts the same system event the Apple key
does, so macOS shows its own HUD and whatever normally handles brightness
keys — the built-in display, or a DDC tool like BetterDisplay for an external
monitor — handles these too. KeyLight never talks to a display or the audio
device itself.

It applies only to keyboards that are not Apple's (identified per event from
the sending HID device), so `fn + F1` on the MacBook keyboard is still F1. The
Mission Control, Spotlight and media-transport keys are deliberately not
remapped; those stay whatever the board sends.

## The menu-bar icon

![The menu-bar icon](docs/menubar-icon.png)

A keycap in sunglasses whose rays light up clockwise with the backlight, shown
above at 0%, 25%, 75% and 100%: grey when the backlight is off, all eight rays
at full, and the first ray comes on at 1% so the key is never dark while the
backlight is on. It also turns grey when KeyLight cannot change the backlight
(Accessibility not granted yet, or the lid is closed); the menu says which. Prefer a plain meter? **menu ▸ Icon** offers Gauge, Arc, Pie or Wedge;
each row previews itself, and the choice persists across launches.

## How it works

- **HotkeyKit** owns a `CGEventTap` that intercepts the brightness media keys
  and the F-keys, matches them against the bindings, and swallows the matched
  event (and its key-up). It reads the sending device from the event so the
  F-key remaps can be scoped to non-Apple keyboards, and treats the `fn` flag
  as implied on F-keys — macOS sets it on every F-key event from every
  keyboard, fn key or not.
- **MediaKeyPoster** sends the Apple media-key event (press + release) at the
  HID level for the F-key remaps. A posted event has no sending device, so the
  tap never sees its own output as a third-party keystroke.
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

### Start at Login

Toggle it from the menu, or from the shell:

```sh
"$HOME/Applications/KeyLight.app/Contents/MacOS/KeyLight" --login on       # or: off, status
```

`install.sh` already runs this for you. Start at Login is `SMAppService.mainApp`, which can only
register the calling process's own bundle — so nothing outside the app can turn
it on, and the command has to be the *installed* binary. A bare `--login`, or
`--login status`, only reports the current state and changes nothing.

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
| [Apollo Monitor](https://github.com/nicholaspsmith/apollo-monitor-menubar) | Apollo audio-interface monitor level, plus a mixer-process watchdog |
| [Battery Time](https://github.com/nicholaspsmith/battery-time-menubar) | Time remaining, power mode, and 24h usage |
| [VPN & DNS](https://github.com/nicholaspsmith/vpn-dns-menubar) | A chameleon for Mullvad + Tailscale state, with a DNS watcher |
| [Process Monitor](https://github.com/nicholaspsmith/MacOS_Process_Monitor) | Process-count sparkline against the per-UID limit |
| **KeyLight** | Ctrl+brightness keys remapped to keyboard backlight |
| [MacRecorder](https://github.com/nicholaspsmith/MacRecorder) | Screen recording with system audio |
| [Media Tracking Killer](https://github.com/nicholaspsmith/media-tracking-killer-menubar) | Kills Apple's media tracking daemons |
| [Download Recycler](https://github.com/nicholaspsmith/download-recycler-menubar) | Sweeps stale files out of ~/Downloads |
| [Barn](https://github.com/nicholaspsmith/menubar-barn) | Hides a block of status icons by width, so it cannot strand one |

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

## License

Copyright (c) 2026 Nicholas Smith. Licensed under the
[Mozilla Public License 2.0](LICENSE). You may use, modify, sell and
redistribute this software, including inside proprietary products, provided
the copyright notice and license stay on these files and any modified
versions of them are made available under the same license.
