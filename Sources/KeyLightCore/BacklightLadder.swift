// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

/// Direction of a backlight adjustment.
public enum Direction: Sendable {
    case up, down
}

/// The steps the backlight keys walk through, on the `0...1` level scale.
///
/// macOS will not light the keyboard below brightness 1/128 (PWM 54 of 960 on
/// an M5 Pro); every positive value clamps there. KeyLight goes lower by
/// holding the PWM itself (`SubFloorHold`), and encodes those duties inside the
/// same scale: a level in `0 < level < 1/128` means a duty of
/// `level * 128` of the native floor. So the icon, slider and controller keep
/// one `Double`, and 0 is still off.
public enum BacklightLadder {
    /// Above 1/16 the keys move in 1/16 steps, the native feel.
    public static let linearStep = 1.0 / 16.0
    /// The lowest level macOS itself will light.
    public static let nativeFloor = 1.0 / 128.0
    /// Sub-floor rungs as fractions of the native floor, brightest first. Each
    /// is about 2/3 of the one above; the last is one PWM tick on a 54-tick
    /// floor, the lowest duty the hardware holds lit.
    public static let subFloorFractions: [Double] = [36, 24, 16, 11, 7, 4, 2, 1].map { $0 / 54 }
    /// The same rungs as levels, brightest first.
    public static let subFloorLevels: [Double] = subFloorFractions.map { $0 * nativeFloor }

    /// Levels closer than this are the same level. Readback comes back as a
    /// `Float`; the closest two rungs differ by about 1.4e-4.
    static let epsilon = 1e-7

    /// The level one key press away. `subFloor: false` leaves out the rungs
    /// below the native floor, for a Mac whose PWM KeyLight cannot read.
    public static func next(current: Double, direction: Direction, subFloor: Bool = true) -> Double {
        let c = max(0, min(1, current))
        let below = subFloor ? subFloorLevels : []
        switch direction {
        case .up:
            if c < linearStep - epsilon {
                // Off, sub-floor, or native between the floor and 1/16:
                // the next rung above, in ascending order.
                let rungs = below.reversed() + [nativeFloor, linearStep]
                return rungs.first { $0 > c + epsilon } ?? linearStep
            }
            return min(1, c + linearStep)
        case .down:
            if c > linearStep + epsilon { return max(linearStep, c - linearStep) }
            let rungs = [nativeFloor] + below + [0]
            return rungs.first { $0 < c - epsilon } ?? 0
        }
    }

    /// True for a level only KeyLight's hold can show.
    public static func isSubFloor(_ level: Double) -> Bool {
        level > epsilon && level < nativeFloor - epsilon
    }

    /// The PWM duty, in ticks, a sub-floor level stands for. Never below 1.
    public static func targetTicks(for level: Double, floorTicks: Double) -> Double {
        max(1, (level / nativeFloor * floorTicks).rounded())
    }

    /// What the menu-bar icon draws: any lit level shows at least 1%, which
    /// lights the key's first ray.
    public static func displayFraction(_ level: Double) -> Double {
        level > epsilon ? max(level, 0.01) : 0
    }

    /// The slider's readout. Sub-floor levels would all round to 0%.
    public static func percentLabel(_ level: Double) -> String {
        if level <= epsilon { return "0%" }
        if level < 0.005 { return "<1%" }
        return "\(Int((level * 100).rounded()))%"
    }
}
