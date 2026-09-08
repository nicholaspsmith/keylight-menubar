import Foundation

/// Which StatusItemKit meter the menu-bar icon is drawn with.
public enum IconStyle: String, CaseIterable, Sendable {
    case key, gauge, arc, pie, wedge

    /// Used when nothing is stored, or what's stored isn't a style we know.
    public static let fallback = IconStyle.key

    /// Human-readable label for the menu.
    public var label: String {
        switch self {
        case .key: return "Key"
        case .gauge: return "Gauge"
        case .arc: return "Arc"
        case .pie: return "Pie"
        case .wedge: return "Wedge"
        }
    }
}

/// Persistence for the chosen `IconStyle`.
public enum IconStyleStore {
    public static let defaultsKey = "iconStyle"

    /// Falls back rather than trapping when the key is absent, holds a
    /// non-string, or names a style this build doesn't know — so downgrading
    /// after a future version adds a style degrades gracefully.
    public static func load(from defaults: UserDefaults) -> IconStyle {
        guard let raw = defaults.string(forKey: defaultsKey),
              let style = IconStyle(rawValue: raw)
        else { return .fallback }
        return style
    }

    public static func save(_ style: IconStyle, to defaults: UserDefaults) {
        defaults.set(style.rawValue, forKey: defaultsKey)
    }
}
