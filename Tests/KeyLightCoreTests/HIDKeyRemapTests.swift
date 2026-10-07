// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
@testable import KeyLightCore

/// The driver-level remap that turns a third-party board's F-keys into the
/// Apple media keys, below Secure Event Input (Safari, password fields).
final class HIDKeyRemapTests: XCTestCase {
    private typealias Entry = HIDKeyRemap.Entry

    func testMapsTheFiveFunctionKeysToConsumerMediaUsages() {
        // Keyboard page 0x07: F1 0x3A, F2 0x3B, F10 0x43, F11 0x44, F12 0x45.
        // Consumer page 0x0C: brightness down 0x70 / up 0x6F, mute 0xE2,
        // volume down 0xEA / up 0xE9.
        XCTAssertEqual(HIDKeyRemap.entries, [
            Entry(src: 0x7_0000_003A, dst: 0xC_0000_0070),
            Entry(src: 0x7_0000_003B, dst: 0xC_0000_006F),
            Entry(src: 0x7_0000_0043, dst: 0xC_0000_00E2),
            Entry(src: 0x7_0000_0044, dst: 0xC_0000_00EA),
            Entry(src: 0x7_0000_0045, dst: 0xC_0000_00E9),
        ])
    }

    func testEnablingAddsOursAndKeepsSomeoneElsesMappings() {
        let capsToEscape = Entry(src: 0x7_0000_0039, dst: 0x7_0000_0029)
        let merged = HIDKeyRemap.merged(existing: [capsToEscape], enabled: true)
        XCTAssertEqual(merged, [capsToEscape] + HIDKeyRemap.entries)
    }

    func testEnablingTwiceIsANoOp() {
        let once = HIDKeyRemap.merged(existing: [], enabled: true)
        XCTAssertEqual(HIDKeyRemap.merged(existing: once, enabled: true), once)
    }

    func testDisablingRemovesOnlyOurs() {
        let capsToEscape = Entry(src: 0x7_0000_0039, dst: 0x7_0000_0029)
        let merged = HIDKeyRemap.merged(existing: HIDKeyRemap.entries + [capsToEscape], enabled: false)
        XCTAssertEqual(merged, [capsToEscape])
    }

    func testOursReplacesAConflictingMappingForTheSameKey() {
        let f1ToA = Entry(src: 0x7_0000_003A, dst: 0x7_0000_0004)
        XCTAssertEqual(HIDKeyRemap.merged(existing: [f1ToA], enabled: true), HIDKeyRemap.entries)
    }
}
