// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import Foundation

/// What must survive a relaunch while a sub-floor level is held.
public enum SubFloorStore {
    /// The held sub-floor level, re-applied at launch.
    public static let parkedLevelKey = "subFloorLevel"
    /// Present only while parked: the auto-brightness setting to put back.
    /// Left behind by a crash, it tells the next launch to clean up.
    public static let pendingRestoreKey = "subFloorRestoreAutoBrightness"

    public static func loadParkedLevel(from defaults: UserDefaults) -> Double? {
        guard let n = defaults.object(forKey: parkedLevelKey) as? NSNumber,
              BacklightLadder.isSubFloor(n.doubleValue) else { return nil }
        return n.doubleValue
    }

    public static func saveParkedLevel(_ level: Double?, to defaults: UserDefaults) {
        if let level { defaults.set(level, forKey: parkedLevelKey) } else { defaults.removeObject(forKey: parkedLevelKey) }
    }

    public static func loadPendingRestore(from defaults: UserDefaults) -> Bool? {
        (defaults.object(forKey: pendingRestoreKey) as? NSNumber)?.boolValue
    }

    public static func savePendingRestore(autoBrightness: Bool?, to defaults: UserDefaults) {
        if let autoBrightness { defaults.set(autoBrightness, forKey: pendingRestoreKey) } else { defaults.removeObject(forKey: pendingRestoreKey) }
    }
}
