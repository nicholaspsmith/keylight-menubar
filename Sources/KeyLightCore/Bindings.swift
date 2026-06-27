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
