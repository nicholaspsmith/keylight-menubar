# Menu-bar icon style picker

**Date:** 2026-08-08
**Status:** approved

## Goal

Let the user choose which of StatusItemKit's level-driven meter styles KeyLight
draws in the menu bar. Today `refreshIcon()` hardcodes `MeterIcon.gauge`;
StatusItemKit already ships `gauge`, `arc`, `pie` and `wedge`, all with the same
`(fraction:color:)` signature. The choice belongs in the status menu (an `Icon`
submenu), persists across launches, and applies immediately.

Out of scope: new icon artwork, a static non-level glyph, a percentage-text
readout, and any preferences-window UI. The four existing meters only.

## Architecture

Two units, split on the AppKit boundary:

- **`KeyLightCore.IconStyle` / `IconStyleStore`** — the identity of a style and
  its persistence. Pure Foundation, no drawing, unit-testable. Mirrors how
  `BindingStore.resolve` is testable independently of the tap.
- **`KeyLight.App`** — maps a style to a `MeterIcon` call and builds the menu.
  Owns everything AppKit.

Rejected alternatives: an `ObservableObject` model like `BindingsModel` (only
earns its keep if SwiftUI binds to it — the menu rebuilds on open, so nothing
observes it); reading `UserDefaults` inline in `App` (saves a file, loses the
test seam for the unknown-persisted-value case).

## Components

### `Sources/KeyLightCore/IconStyle.swift` (new)

```swift
public enum IconStyle: String, CaseIterable, Sendable {
    case gauge, arc, pie, wedge
    public static let fallback = IconStyle.gauge
    public var label: String    // "Gauge", "Arc", "Pie", "Wedge"
}

public enum IconStyleStore {
    public static let defaultsKey = "iconStyle"
    public static func load(from defaults: UserDefaults) -> IconStyle
    public static func save(_ style: IconStyle, to defaults: UserDefaults)
}
```

`load` returns `.fallback` when the key is absent or holds a string that doesn't
match a case, so downgrading after a future version adds a style degrades
gracefully instead of trapping.

`CaseIterable` order (`gauge, arc, pie, wedge`) is the menu order.

### `Sources/KeyLight/main.swift` (modified)

- New stored property `iconStyle`, initialised from
  `IconStyleStore.load(from: .standard)`.
- New `makeIcon(_ style: IconStyle, fraction: CGFloat, color: NSColor) -> NSImage`
  switching over the four `MeterIcon` functions.
- `refreshIcon()` routes **both** existing branches through `makeIcon` with
  `iconStyle`. The active branch keeps `.black` + `isTemplate = true`; the
  inactive branch (tap not running, or backlight suppressed) keeps
  `.systemGray`. No change to that logic — only which drawing function runs.
- `buildMenu` gains an `Icon` submenu between `Preferences…` and
  `Start at Login`.
- `@objc selectIcon(_ sender: NSMenuItem)` reads the style, assigns it, calls
  `IconStyleStore.save`, then `refreshIcon()` so the menu bar updates at once.

### Menu

```
Backlight: 62%
────────────────────
Preferences…      ⌘,
Icon             ▸    ✓ ◔ Gauge
Start at Login          ◜ Arc
────────────────────    ◕ Pie
Quit KeyLight     ⌘Q    ◔ Wedge
```

Each submenu row carries an 18×18 template preview of its own style. Previews
render at a **fixed fraction of 0.6**, not the live backlight level: at 0% the
arc, pie and wedge previews are all an empty or faint disk and become mutually
indistinguishable — exactly when someone adjusting the backlight is likely to
open the menu. The preview's job is to show the shape; the live level is already
stated two rows up ("Backlight: 62%") and drawn in the menu bar itself.

Previews are templates (`.black` ink, `isTemplate = true`) so macOS tints them
for light/dark appearance and menu-row highlight, matching the active status
icon. They are drawn at `MeterIcon`'s native 18pt — resizing the `NSImage` would
re-invoke the drawing handler with a smaller rect while the hardcoded radii stay
put, clipping the glyph.

The active style is marked with `state = .on`. The style travels on the menu
item as `representedObject` (the raw `String`, which is ObjC-bridgeable).

## Data flow

```
launch ──► IconStyleStore.load(.standard) ──► App.iconStyle
                                                  │
menu opens ──► buildMenu ──► preview per case ────┤ (state = .on for active)
                                                  │
user clicks ──► selectIcon ──► App.iconStyle ─────┼──► IconStyleStore.save
                                                  └──► refreshIcon ──► setIcon
poll tick (5s) / key press ──► refreshIcon ───────┘
```

## Error handling

The only failure mode is a missing or unrecognised persisted value, handled by
`load` returning `.fallback`. Writing to `UserDefaults` cannot meaningfully fail
here. A menu item arriving at `selectIcon` without a decodable
`representedObject` is a programming error, not a runtime condition — it returns
without changing state.

## Testing

`Tests/KeyLightCoreTests/IconStyleTests.swift`, against an isolated
`UserDefaults(suiteName:)` so the developer's real preferences are untouched:

- `load` on an empty store returns `.fallback`.
- Every case round-trips through `save` → `load`.
- An unknown string under `defaultsKey` loads as `.fallback`.
- A non-string value under `defaultsKey` loads as `.fallback`.

The drawing and menu-construction paths are AppKit-side and stay uncovered by
unit tests, consistent with the rest of the KeyLight target; they get verified
by running the app.

## Documentation

README gains one line under "What it does" noting the `Icon` submenu and the
four available styles.
