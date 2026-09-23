// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import Combine
import Foundation
import HotkeyKit
import KeyLightCore

/// Single source of truth for the active bindings. Loads user overrides from
/// `UserDefaults`, merges them over the built-in defaults, persists changes, and
/// notifies observers (the prefs UI via `@Published`, the tap via `onChange`).
///
/// `bindings` is the rebindable pair the Preferences window shows;
/// `tapBindings` adds the fixed ctrl+F1/F2 aliases and, while the toggle is on,
/// the function-key remaps for third-party keyboards.
final class BindingsModel: ObservableObject {
    @Published private(set) var bindings: [Binding]

    /// Called whenever the tap's bindings change (e.g. to re-register the tap).
    var onChange: (([Binding]) -> Void)?

    /// F1/F2/F10/F11/F12 → brightness / mute / volume on non-Apple keyboards.
    var functionKeysOnOtherKeyboards: Bool {
        didSet {
            UserDefaults.standard.set(functionKeysOnOtherKeyboards, forKey: Self.functionKeysKey)
            recompute()
        }
    }

    var tapBindings: [Binding] {
        BindingStore.resolveAll(overrides: overrides, functionKeysOnOtherKeyboards: functionKeysOnOtherKeyboards)
    }

    private var overrides: [String: Trigger]
    private let defaultsKey = "bindingOverrides"
    static let functionKeysKey = "functionKeysOnOtherKeyboards"

    init() {
        overrides = Self.loadOverrides(key: defaultsKey)
        bindings = BindingStore.resolve(overrides: overrides)
        // On by default: an absent key reads as enabled.
        functionKeysOnOtherKeyboards =
            UserDefaults.standard.object(forKey: Self.functionKeysKey) as? Bool ?? true
    }

    func setOverride(token: String, trigger: Trigger) {
        overrides[token] = trigger
        persist()
        recompute()
    }

    func reset(token: String) {
        overrides.removeValue(forKey: token)
        persist()
        recompute()
    }

    /// Whether a token currently uses a user override (vs the built-in default).
    func isOverridden(_ token: String) -> Bool { overrides[token] != nil }

    private func recompute() {
        bindings = BindingStore.resolve(overrides: overrides)
        onChange?(tapBindings)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(overrides) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private static func loadOverrides(key: String) -> [String: Trigger] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: Trigger].self, from: data)
        else { return [:] }
        return dict
    }
}
