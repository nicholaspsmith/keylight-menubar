# Changelog

Every push to `main` is a release. Before pushing, add a `## [X.Y.Z] - YYYY-MM-DD`
section at the top with `- ` entries (minor for features, patch for fixes); if an
`## [Unreleased]` section is waiting, turn it into that section. GitHub tags it
and publishes the section as the release notes; a push or pull request
without one is refused (`[no release]` in the tip commit is the only exception).
Versions follow [Semantic Versioning](https://semver.org/). The full rule:
[StatusItemKit — Releases](https://github.com/nicholaspsmith/StatusItemKit#releases-every-push-is-one).

## [1.3.0] - 2026-10-01

- Lumen's menu-bar icon is now his illustrated keycap; the rays light up with the backlight level

## [1.2.1] - 2026-09-29

- Fixed: after the keyboard backlight turned off from inactivity, KeyLight's slider and hotkeys did nothing until a key was pressed. Adjusting now relights the keys, and they turn off again once the timeout passes with no input
- Fixed: the menu said "Backlight suppressed (lid closed)" with the lid open whenever macOS had turned the backlight off for inactivity; it now says that only when the lid is actually closed, and shows the slider otherwise

## [1.2.0] - 2026-09-28

- The menu-bar icon hides itself while there is no keyboard backlight to control — lid closed on an external display, or no backlight API — and comes back when there is

## [1.1.1] - 2026-09-28

- `install.sh` now asks whether to turn on Start at Login (skipped when it is already on, or when there is no terminal to ask in) instead of turning it on unasked, then relaunches the app, quitting any running copy first so the new build takes over
- docs: README shows the version and how releases carry the changelog

## [1.1.0] - 2026-09-26

### Dimmer than macOS allows

The keyboard backlight now goes below macOS's lowest level. Under 1/16, each press steps through macOS's floor (1/128) and then eight more levels KeyLight adds beneath it, down to a single PWM tick: 1/54 of the floor. Then off.

macOS clamps every brightness above zero to its floor, so KeyLight holds these levels itself by steering CoreBrightness's own fade and reading the backlight's actual duty from the IO registry. The hardware keeps running at 25 kHz, so nothing flickers.

While a sub-floor level is held:
- **Backlight Timeout still works:** KeyLight runs the timeout itself with the same setting.
- **Auto-brightness is paused,** and back on when you leave the sub-floor range or quit.
- **A change made elsewhere wins:** Control Center or another app setting the backlight takes over.
- **Quitting** leaves the keys at macOS's floor with everything restored; the level returns at the next launch. After a crash, the next launch cleans up first.

The cost is a CoreBrightness preference flip about once a second at the lowest levels. Nothing extra runs at macOS's own levels.

### Backlight Timeout

**Menu ▸ Backlight Timeout** sets how long the keys stay lit without input: 1–5 seconds, 1, 2, 5 or 10 minutes, or never. System Settings only offers 5 seconds and up.

### Also
- SIGTERM, SIGINT and SIGHUP quit KeyLight cleanly.

Merged in #3. Design notes: `docs/superpowers/specs/2026-09-25-sub-floor-backlight-design.md`.

## [1.0.0] - 2026-09-23

The first release of KeyLight, a standalone menu-bar app for the MacBook keyboard backlight. It replaces a BetterTouchTool setup.

### Features
- **Ctrl + brightness keys** step the keyboard backlight up and down in 1/16 steps; the display brightness doesn't change.
- **Brightness slider** at the top of the menu.
- **Third-party keyboards:** F1/F2 become brightness, F10–F12 mute and volume, as on an Apple keyboard, for non-Apple keyboards only. Ctrl + F1/F2 drive the backlight on any keyboard.
- **Menu-bar icon:** a keycap whose rays light with the backlight level. Gauge, Arc, Pie or Wedge meters are available from **Icon**. The icon turns grey while macOS suppresses the backlight (lid closed) or Accessibility isn't granted.
- **Start at Login** from the menu, or `KeyLight --login on|off|status`; the installer turns it on.
- **Rebindable** backlight shortcuts in Preferences.
- Steps aside while Barn reveals hidden menu-bar icons.
- The event tap re-asserts itself every poll, so other apps can't leapfrog it.
- Stable local code signing, so the Accessibility grant survives rebuilds.
- The menu shows the version it was built from.

Licensed under the Mozilla Public License 2.0.
