# Changelog

Every push to `main` is a release. Add a `## [X.Y.Z] - YYYY-MM-DD` section at
the top (minor for features, patch for fixes); GitHub tags it and publishes
the section as the release notes. Versions follow [Semantic
Versioning](https://semver.org/).

## [Unreleased]

- docs: README shows the version and how releases carry the changelog

## [1.1.0] - 2026-09-26

- feat: keyboard backlight below macOS's floor, down to one PWM tick
- feat(core): sub-floor ladder, PWM floor calibration, hold state machine
- docs: sub-floor backlight design
- feat: Backlight Timeout — the keys go dark after 1–5 s, 1–10 min, or never

## [1.0.0] - 2026-09-23

- feat: the menu shows the version it was built from
- feat: brightness and volume on third-party keyboards' F-keys, ctrl+F1/F2 for the backlight
- test: the icon menu has led with the key mascot since it was added
- LICENSE: name the copyright holder above the MPL text
- License: Mozilla Public License 2.0
- docs: document the --login flag
- feat: --login on|off|status, and register Start at Login on install
- docs: Curtain is now Barn
- docs: Apollo Monitor described without the vendor name
- docs: drop instructions that assume other software the reader may not use
- docs: icon strip shows 0/25/75/100% instead of repeating the grey state
- docs: the character menu-bar icon, rendered from code, and what its states mean
- feat: brightness slider at the top of the menu
- feat: Key icon — rays light with the backlight level (default; meters still available)
- feat: app icon from the Menubarn mascot
- docs: mention the Menubarn widget library
- docs: why a standalone app beats a SwiftBar plugin
- docs: add the Menubarn mascot to the README
- Advertise the menu-bar suite
- feat: yield the status item during a curtain peek
- Let the user pick the menu-bar meter style
- docs: spec the menu-bar icon style picker
- Re-assert the tap each poll tick so other apps can't leapfrog it
- Gray out the gauge while macOS suppresses the backlight
- Use the default menu-bar color for the active status icon
- docs: explain stable signing so Accessibility survives rebuilds
- Initial commit: KeyLight — keyboard-backlight menu-bar app
