// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

/// The F-key → media-key remap, as a HID `UserKeyMapping` (what `hidutil`
/// sets). It runs in the HID driver, before Secure Event Input, so it keeps
/// working in Safari and password fields, where the event tap is blind to
/// plain key presses. The tap's own remap stays as a fallback.
///
/// Usages are `(page << 32) | usage`: page 0x07 is the keyboard, 0x0C consumer.
public enum HIDKeyRemap {
    public struct Entry: Equatable, Sendable {
        public var src: Int64
        public var dst: Int64
        public init(src: Int64, dst: Int64) { self.src = src; self.dst = dst }
    }

    public static let srcKey = "HIDKeyboardModifierMappingSrc"
    public static let dstKey = "HIDKeyboardModifierMappingDst"

    private static func key(_ usage: Int64) -> Int64 { 0x7_0000_0000 | usage }
    private static func consumer(_ usage: Int64) -> Int64 { 0xC_0000_0000 | usage }

    /// Same keys as `BindingStore.functionKeyRemaps`.
    public static let entries: [Entry] = [
        Entry(src: key(0x3A), dst: consumer(0x70)),   // F1  → brightness down
        Entry(src: key(0x3B), dst: consumer(0x6F)),   // F2  → brightness up
        Entry(src: key(0x43), dst: consumer(0xE2)),   // F10 → mute
        Entry(src: key(0x44), dst: consumer(0xEA)),   // F11 → volume down
        Entry(src: key(0x45), dst: consumer(0xE9)),   // F12 → volume up
    ]

    /// A keyboard's mapping with ours added (or removed), leaving any other
    /// mapping on it alone. Ours wins a clash over the same source key.
    public static func merged(existing: [Entry], enabled: Bool) -> [Entry] {
        let ours = Set(entries.map(\.src))
        let others = existing.filter { !ours.contains($0.src) }
        return enabled ? others + entries : others
    }
}
