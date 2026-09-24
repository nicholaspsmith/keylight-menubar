// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import Foundation

/// How long the keyboard stays lit with no input before macOS turns the
/// backlight off. It relights on the next keypress. This is the same knob as
/// System Settings ▸ Keyboard ▸ "Turn keyboard backlight off after … of
/// inactivity", which only offers 5 s upwards; macOS accepts any number of
/// seconds, and 0 means never.
public enum BacklightTimeout: Double, CaseIterable, Sendable {
    case seconds1 = 1, seconds2 = 2, seconds3 = 3, seconds4 = 4, seconds5 = 5
    case minutes1 = 60, minutes2 = 120, minutes5 = 300, minutes10 = 600
    case never = 0

    public var seconds: Double { rawValue }

    /// The menu row that matches a value read back from macOS, if any. A
    /// value chosen in System Settings that isn't on our menu (10 s, 30 s)
    /// matches nothing, so no row claims it.
    public init?(seconds: Double) {
        self.init(rawValue: seconds)
    }

    /// Human-readable label for the menu.
    public var label: String {
        switch self {
        case .never: return "Never"
        case .seconds1: return "1 second"
        case .seconds2, .seconds3, .seconds4, .seconds5: return "\(Int(seconds)) seconds"
        case .minutes1: return "1 minute"
        case .minutes2, .minutes5, .minutes10: return "\(Int(seconds / 60)) minutes"
        }
    }
}

/// Persistence for the chosen `BacklightTimeout`. Unlike the icon style there
/// is no fallback: when nothing has been chosen, macOS keeps whatever System
/// Settings says and KeyLight leaves it alone.
public enum BacklightTimeoutStore {
    public static let defaultsKey = "backlightTimeoutSeconds"

    public static func load(from defaults: UserDefaults) -> BacklightTimeout? {
        guard let n = defaults.object(forKey: defaultsKey) as? NSNumber else { return nil }
        return BacklightTimeout(seconds: n.doubleValue)
    }

    public static func save(_ timeout: BacklightTimeout, to defaults: UserDefaults) {
        defaults.set(timeout.seconds, forKey: defaultsKey)
    }
}
