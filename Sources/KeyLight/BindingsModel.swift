import Combine
import Foundation
import HotkeyKit
import KeyLightCore

/// Single source of truth for the active bindings. Loads user overrides from
/// `UserDefaults`, merges them over the built-in defaults, persists changes, and
/// notifies observers (the prefs UI via `@Published`, the tap via `onChange`).
final class BindingsModel: ObservableObject {
    @Published private(set) var bindings: [Binding]

    /// Called whenever the resolved bindings change (e.g. to re-register the tap).
    var onChange: (([Binding]) -> Void)?

    private var overrides: [String: Trigger]
    private let defaultsKey = "bindingOverrides"

    init() {
        overrides = Self.loadOverrides(key: defaultsKey)
        bindings = BindingStore.resolve(overrides: overrides)
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
        onChange?(bindings)
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
