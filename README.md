# KeyLight

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
