// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import CoreGraphics
import HotkeyKit

/// The actions KeyLight knows how to perform, identified by their binding token.
public enum BacklightAction: String, CaseIterable, Sendable {
    case up = "backlight.up"
    case down = "backlight.down"

    /// Human-readable label for the preferences UI.
    public var label: String {
        switch self {
        case .up: return "Backlight Up"
        case .down: return "Backlight Down"
        }
    }

    public var direction: Direction {
        switch self {
        case .up: return .up
        case .down: return .down
        }
    }
}

/// Built-in default bindings (the drop-in of the BetterTouchTool setup) plus
/// merge logic for user overrides. Pure + testable.
///
/// Media codes: `NX_KEYTYPE_BRIGHTNESS_UP = 2`, `NX_KEYTYPE_BRIGHTNESS_DOWN = 3`.
public enum BindingStore {
    public static let defaults: [Binding] = [
        Binding(token: BacklightAction.up.rawValue,   trigger: .mediaKey(2, .control)),
        Binding(token: BacklightAction.down.rawValue, trigger: .mediaKey(3, .control)),
    ]

    /// Merge user `overrides` (token → replacement trigger) over the defaults.
    /// Overrides for unknown tokens are ignored; binding order is preserved.
    public static func resolve(overrides: [String: Trigger]) -> [Binding] {
        defaults.map { binding in
            guard let trigger = overrides[binding.token] else { return binding }
            var updated = binding
            updated.trigger = trigger
            return updated
        }
    }
}

/// The Apple-keyboard media keys KeyLight gives back to third-party boards,
/// identified by their binding token. Each posts the same system-defined
/// event an Apple keyboard sends, so macOS (or whatever handles brightness
/// keys, BetterDisplay say) does the actual work and shows its own HUD.
public enum MediaAction: String, CaseIterable, Sendable {
    case brightnessDown = "media.brightnessDown"
    case brightnessUp = "media.brightnessUp"
    case mute = "media.mute"
    case volumeDown = "media.volumeDown"
    case volumeUp = "media.volumeUp"

    /// `NX_KEYTYPE_*` from IOKit's `ev_keymap.h`.
    public var nxKeyType: Int32 {
        switch self {
        case .volumeUp: return 0
        case .volumeDown: return 1
        case .brightnessUp: return 2
        case .brightnessDown: return 3
        case .mute: return 7
        }
    }
}

/// ANSI keycodes of the F-keys KeyLight remaps.
public enum FunctionKey {
    public static let f1: CGKeyCode = 122
    public static let f2: CGKeyCode = 120
    public static let f10: CGKeyCode = 109
    public static let f11: CGKeyCode = 103
    public static let f12: CGKeyCode = 111
}

extension BindingStore {
    /// ctrl+F1 / ctrl+F2 drive the backlight the way ctrl+brightness does.
    /// Fixed (not shown in Preferences, untouched by overrides) and on any
    /// keyboard: on an Apple board ctrl+fn+F1 is what reaches us, and nothing
    /// else claims it.
    public static let backlightAliases: [Binding] = [
        Binding(token: BacklightAction.down.rawValue, trigger: .key(FunctionKey.f1, .control)),
        Binding(token: BacklightAction.up.rawValue, trigger: .key(FunctionKey.f2, .control)),
    ]

    /// F1/F2/F10/F11/F12 → the media keys an Apple keyboard has there. Only on
    /// keyboards that are not Apple's, so fn+F1 on the MacBook stays F1.
    public static let functionKeyRemaps: [Binding] = [
        Binding(token: MediaAction.brightnessDown.rawValue, trigger: .key(FunctionKey.f1, []), scope: .nonAppleKeyboards),
        Binding(token: MediaAction.brightnessUp.rawValue, trigger: .key(FunctionKey.f2, []), scope: .nonAppleKeyboards),
        Binding(token: MediaAction.mute.rawValue, trigger: .key(FunctionKey.f10, []), scope: .nonAppleKeyboards),
        Binding(token: MediaAction.volumeDown.rawValue, trigger: .key(FunctionKey.f11, []), scope: .nonAppleKeyboards),
        Binding(token: MediaAction.volumeUp.rawValue, trigger: .key(FunctionKey.f12, []), scope: .nonAppleKeyboards),
    ]

    /// Everything the tap should listen for: the two rebindable rows (with
    /// overrides applied) first, then the fixed aliases and, when enabled, the
    /// function-key remaps.
    public static func resolveAll(overrides: [String: Trigger], functionKeysOnOtherKeyboards: Bool) -> [Binding] {
        resolve(overrides: overrides)
            + backlightAliases
            + (functionKeysOnOtherKeyboards ? functionKeyRemaps : [])
    }
}
