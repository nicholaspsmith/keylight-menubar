// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import Foundation
import IOKit
import KeyLightCore

/// Live reads of the keyboard backlight's PWM from the IO registry. This is
/// the ground truth for the backlight: CoreBrightness reads back whatever was
/// last asked for, not what the LEDs are doing.
final class KeyboardPWM {
    private let entry: io_registry_entry_t
    /// The duty CoreBrightness will not go below, in ticks.
    let floorTicks: Double

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("kbd-backlight"))
        guard service != 0 else { return nil }
        entry = service
        let high = Self.int(service, "high-period"), low = Self.int(service, "low-period")
        let period = (high != nil && low != nil) ? high! + low! : nil
        floorTicks = PWMCalibration.floorTicks(
            percentTable: Self.data(service, "nits-to-pwm-percentage-part2"),
            period: period
        )
        // Reading the duty is the whole point; without it there is no hold.
        guard high != nil else { IOObjectRelease(service); return nil }
    }

    deinit { IOObjectRelease(entry) }

    /// High ticks of the current period, or 0 while the PWM is disabled (its
    /// last duty lingers in the registry then).
    var duty: Int {
        guard Self.bool(entry, "enabled") != false else { return 0 }
        return Self.int(entry, "high-period") ?? 0
    }

    private static func property(_ e: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(e, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
    private static func int(_ e: io_registry_entry_t, _ key: String) -> Int? { property(e, key) as? Int }
    private static func bool(_ e: io_registry_entry_t, _ key: String) -> Bool? { property(e, key) as? Bool }
    private static func data(_ e: io_registry_entry_t, _ key: String) -> Data? { property(e, key) as? Data }
}

/// Whether the built-in display's lid is shut, from the power manager.
enum Clamshell {
    static var isClosed: Bool {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { return false }
        defer { IOObjectRelease(root) }
        let v = IORegistryEntryCreateCFProperty(root, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        return (v as? Bool) ?? false
    }
}
