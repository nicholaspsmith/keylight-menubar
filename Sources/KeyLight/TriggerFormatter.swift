import CoreGraphics
import HotkeyKit

/// Renders a `Trigger` as a glyph string for the prefs UI, e.g. "⌃⌥⌘C" or
/// "⌃Brightness Up".
enum TriggerFormatter {
    static func string(_ trigger: Trigger) -> String {
        switch trigger {
        case let .key(code, mods):
            return modifierString(mods) + keyName(code)
        case let .mediaKey(code, mods):
            return modifierString(mods) + mediaName(code)
        }
    }

    static func modifierString(_ m: Modifiers) -> String {
        var s = ""
        if m.contains(.control) { s += "⌃" }
        if m.contains(.option)  { s += "⌥" }
        if m.contains(.shift)   { s += "⇧" }
        if m.contains(.command) { s += "⌘" }
        if m.contains(.fn)      { s += "fn " }
        return s
    }

    static func mediaName(_ code: Int32) -> String {
        switch code {
        case 2:  return "Brightness Up"
        case 3:  return "Brightness Down"
        default: return "Media(\(code))"
        }
    }

    /// Compact ANSI keycode → label map for the common keys; falls back to the
    /// numeric code for anything unusual.
    static func keyName(_ code: CGKeyCode) -> String {
        keyNames[code] ?? "Key \(code)"
    }

    private static let keyNames: [CGKeyCode: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C",
        9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[",
        34: "I", 35: "P", 36: "Return", 37: "L", 38: "J", 39: "'", 40: "K",
        41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab",
        49: "Space", 50: "`", 51: "Delete", 53: "Esc",
    ]
}
