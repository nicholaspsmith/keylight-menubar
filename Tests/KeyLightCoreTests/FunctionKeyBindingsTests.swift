// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
import HotkeyKit
@testable import KeyLightCore

/// Third-party keyboards send F1–F12 as plain F-keys. KeyLight gives the five
/// Apple-board media keys back (F1/F2 brightness, F10–F12 mute/volume) and
/// makes ctrl+F1/F2 drive the backlight as ctrl+brightness does.
final class FunctionKeyBindingsTests: XCTestCase {
    private func binding(_ token: String, in list: [Binding], trigger: Trigger) -> Binding? {
        list.first { $0.token == token && $0.trigger == trigger }
    }

    func testMediaActionsPostTheApplePayload() {
        // NX_KEYTYPE_SOUND_UP 0, SOUND_DOWN 1, BRIGHTNESS_UP 2, BRIGHTNESS_DOWN 3, MUTE 7
        XCTAssertEqual(MediaAction.volumeUp.nxKeyType, 0)
        XCTAssertEqual(MediaAction.volumeDown.nxKeyType, 1)
        XCTAssertEqual(MediaAction.brightnessUp.nxKeyType, 2)
        XCTAssertEqual(MediaAction.brightnessDown.nxKeyType, 3)
        XCTAssertEqual(MediaAction.mute.nxKeyType, 7)
    }

    func testFunctionKeysMapToMediaActionsOnOtherKeyboardsOnly() {
        let all = BindingStore.resolveAll(overrides: [:], functionKeysOnOtherKeyboards: true)
        let expected: [(CGKeyCode, MediaAction)] = [
            (122, .brightnessDown), (120, .brightnessUp),   // F1, F2
            (109, .mute), (103, .volumeDown), (111, .volumeUp),   // F10, F11, F12
        ]
        for (code, action) in expected {
            let b = binding(action.rawValue, in: all, trigger: .key(code, []))
            XCTAssertNotNil(b, "\(action) on key \(code)")
            XCTAssertEqual(b?.scope, .nonAppleKeyboards, "\(action)")
            XCTAssertEqual(b?.repeatsOnHold, true, "\(action) repeats while held")
        }
    }

    func testCtrlF1AndF2DriveTheBacklightOnAnyKeyboard() {
        let all = BindingStore.resolveAll(overrides: [:], functionKeysOnOtherKeyboards: true)
        let down = binding(BacklightAction.down.rawValue, in: all, trigger: .key(122, .control))
        let up = binding(BacklightAction.up.rawValue, in: all, trigger: .key(120, .control))
        XCTAssertEqual(down?.scope, .anyKeyboard)
        XCTAssertEqual(up?.scope, .anyKeyboard)
    }

    func testRebindableDefaultsComeFirstAndStayRebindable() {
        let custom = Trigger.key(8, [.control, .option, .command])
        let all = BindingStore.resolveAll(overrides: ["backlight.up": custom], functionKeysOnOtherKeyboards: true)
        XCTAssertEqual(Array(all.prefix(2)), BindingStore.resolve(overrides: ["backlight.up": custom]))
        // The fixed ctrl+F2 alias is untouched by the override.
        XCTAssertNotNil(binding(BacklightAction.up.rawValue, in: all, trigger: .key(120, .control)))
    }

    func testToggleOffRemovesTheMediaRemapsButKeepsBacklightAliases() {
        let all = BindingStore.resolveAll(overrides: [:], functionKeysOnOtherKeyboards: false)
        XCTAssertFalse(all.contains { MediaAction(rawValue: $0.token) != nil })
        XCTAssertNotNil(binding(BacklightAction.down.rawValue, in: all, trigger: .key(122, .control)))
        XCTAssertNotNil(binding(BacklightAction.up.rawValue, in: all, trigger: .key(120, .control)))
    }

    func testPreferencesListIsStillJustTheTwoRebindableRows() {
        XCTAssertEqual(BindingStore.defaults.map(\.token), ["backlight.up", "backlight.down"])
    }
}
