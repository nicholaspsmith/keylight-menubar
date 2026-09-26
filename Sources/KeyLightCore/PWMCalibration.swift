// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import Foundation

/// Finds the keyboard backlight's native floor, in PWM ticks.
///
/// The `kbd-backlight` device-tree node carries a calibration table,
/// `nits-to-pwm-percentage-part2`, of little-endian 16.16 fixed-point duty
/// percentages. Its first entry is the lowest duty CoreBrightness will drive
/// (5.6% on an M5 Pro, 54 of 960 ticks).
public enum PWMCalibration {
    public static let fallbackPeriod = 960
    public static let fallbackFloorTicks = 54.0

    public static func floorTicks(percentTable: Data?, period: Int?) -> Double {
        let period = Double(period ?? fallbackPeriod)
        guard let table = percentTable, table.count >= 4 else { return fallbackFloorTicks }
        let raw = table.prefix(4).enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8 * UInt32($1.offset)) }
        let percent = Double(raw) / 65536
        // A floor is a few percent. Anything else is not the table we know.
        guard percent > 0.1, percent < 20 else { return fallbackFloorTicks }
        return (percent / 100 * period).rounded()
    }
}
