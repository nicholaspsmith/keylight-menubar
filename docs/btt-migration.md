# BetterTouchTool migration record

KeyLight replaces the **only** real functionality BTT was used for: two global
keyboard shortcuts that drive the keyboard backlight. This file preserves the
exact BTT configuration so the replacement can be verified / restored.

## What BTT actually had (audited 2026-06-26)

Full audit of the BTT data store found 6 configured rows; only the two keyboard
shortcuts below are real, user-configured functionality:

| BTT trigger | KeyCode | Modifier | On | Action | Notes |
|-------------|---------|----------|----|--------|-------|
| ⌃ Brightness Down (⌃F1) | `1003` | `262144` (Control) | down | `32` Keyboard Illumination Down | UUID C070FB04… |
| ⌃ Brightness Up (⌃F2)   | `1002` | `262144` (Control) | down | `31` Keyboard Illumination Up   | UUID 501B3F4D… |

The other rows were **inert BTT defaults**, not user setup, and are safely
discarded:
- Two trackpad gestures ("Pinch In" / "Pinch Out", types 115/116) from the
  *Default* preset, both wired to action `366` = "Continue With Next Action"
  (a no-op). They did nothing.

So nothing real is lost by removing BTT.

## Keycode reference

BTT's `BTTShortcutKeyCode` 1002/1003 are the system **media** keys (this Mac runs
in media-key mode, "Use F1/F2 as standard function keys" OFF). They correspond to
the `NSSystemDefined` (subtype 8) media-key codes:

| Physical key | BTT code | NX media code | Direction |
|--------------|----------|---------------|-----------|
| Brightness Up (F2)   | 1002 | `NX_KEYTYPE_BRIGHTNESS_UP` = **2** | backlight up |
| Brightness Down (F1) | 1003 | `NX_KEYTYPE_BRIGHTNESS_DOWN` = **3** | backlight down |

## KeyLight equivalent (must stay in sync)

`BindingStore.defaults` in `Sources/KeyLightCore/Bindings.swift`:

```swift
Binding(token: "backlight.up",   trigger: .mediaKey(2, .control))  // ⌃ Brightness Up
Binding(token: "backlight.down", trigger: .mediaKey(3, .control))  // ⌃ Brightness Down
```

`HotkeyTap` matches Control + the brightness media key, swallows the event (so
display brightness doesn't change), and `CoreBrightnessBacklight` steps the
keyboard backlight — the same end effect as BTT's "Keyboard Illumination Up/Down".

## Verifying the replacement

1. Grant KeyLight **Accessibility** (System Settings ▸ Privacy & Security ▸
   Accessibility), or menu ▸ "⚠ Grant Accessibility…".
2. **Lid open** (the internal backlight is suppressed in clamshell): press
   `Ctrl + Brightness Up` / `Ctrl + Brightness Down` — the keyboard backlight
   changes and the display brightness does **not**.

## Restoring BTT (if ever needed)

BTT was quarantined, not deleted: `~/.disabled-apps/BetterTouchTool.app`. Move it
back to `~/Applications`, relaunch, and re-add the two triggers above (record the
media keys with BTT's in-app recorder; hand-coding keycode 122/120 won't match —
the keys emit media codes 1002/1003).
