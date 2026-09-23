// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import KeyLightCore

/// Posts the system-defined media-key event an Apple keyboard sends — press
/// then release — at the HID level, so the OS handles it exactly as it would
/// the real key: HUD, step size, mute toggle, and whatever else is listening
/// for brightness keys (BetterDisplay's DDC control, say).
///
/// A posted event has no HID sender, so HotkeyKit treats it as coming from an
/// Apple keyboard and the `.nonAppleKeyboards` remaps never see their own
/// output.
enum MediaKeyPoster {
    static func post(_ action: MediaAction) {
        post(keyType: action.nxKeyType, down: true)
        post(keyType: action.nxKeyType, down: false)
    }

    private static func post(keyType: Int32, down: Bool) {
        // data1: key type in the high word, then 0x0A (down) / 0x0B (up) in the
        // second byte — the NX_SYSDEFINED subtype-8 payload HotkeyKit decodes.
        let state = down ? 0x0A : 0x0B
        let data1 = (Int(keyType) << 16) | (state << 8)
        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        ) else { return }
        event.cgEvent?.post(tap: .cghidEventTap)
    }
}
