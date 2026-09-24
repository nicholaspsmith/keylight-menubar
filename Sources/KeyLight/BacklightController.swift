// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import Foundation
import ObjectiveC.runtime

/// Reads and writes the keyboard backlight level (`0...1`).
protocol BacklightController: AnyObject {
    var isAvailable: Bool { get }
    /// True when the backlight is currently suppressed (e.g. clamshell / lid
    /// closed). Sets are accepted but no-op while suppressed.
    var isSuppressed: Bool { get }
    func currentLevel() -> Double?
    @discardableResult func setLevel(_ level: Double) -> Bool
    /// Seconds of inactivity before macOS turns the backlight off; 0 = never.
    /// The same setting as System Settings ▸ Keyboard's inactivity timeout.
    func idleDimTime() -> Double?
    @discardableResult func setIdleDimTime(_ seconds: Double) -> Bool
}

/// Private-`CoreBrightness` implementation, validated on macOS 26 / Apple
/// Silicon. Uses `KeyboardBrightnessClient`; calls its scalar ObjC methods via
/// typed IMPs (private API has no Swift bridging header). All values clamp to
/// `0...1`. The built-in keyboard id is discovered, never hardcoded.
final class CoreBrightnessBacklight: BacklightController {
    private let cls: NSObject.Type
    private let client: NSObject
    private let keyboardID: Int64

    init?() {
        let path = "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
        guard dlopen(path, RTLD_NOW) != nil,
              let cls = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type
        else { return nil }
        let client = cls.init()
        guard let id = Self.builtInKeyboardID(cls: cls, client: client) else { return nil }
        self.cls = cls
        self.client = client
        self.keyboardID = id
    }

    var isAvailable: Bool { true }

    var isSuppressed: Bool {
        Self.boolFor("isBacklightSuppressedOnKeyboard:", cls, client, keyboardID) ?? false
    }

    func currentLevel() -> Double? {
        guard let f = Self.floatFor("brightnessForKeyboard:", cls, client, keyboardID),
              f >= 0, f.isFinite else { return nil }
        return Double(f)
    }

    @discardableResult
    func setLevel(_ level: Double) -> Bool {
        let v = Float(min(1.0, max(0.0, level)))
        return Self.setBrightness(v, cls, client, keyboardID) ?? false
    }

    func idleDimTime() -> Double? {
        guard let d = Self.doubleFor("idleDimTimeForKeyboard:", cls, client, keyboardID),
              d >= 0, d.isFinite else { return nil }
        return d
    }

    @discardableResult
    func setIdleDimTime(_ seconds: Double) -> Bool {
        guard seconds >= 0, seconds.isFinite else { return false }
        return Self.setIdleDimTime(seconds, cls, client, keyboardID) ?? false
    }

    // MARK: - Private ObjC bridging (typed IMP calls; scalar args/returns)

    private static func builtInKeyboardID(cls: NSObject.Type, client: NSObject) -> Int64? {
        let sel = NSSelectorFromString("copyKeyboardBacklightIDs")
        guard let m = class_getInstanceMethod(cls, sel) else { return nil }
        typealias Copy = @convention(c) (AnyObject, Selector) -> Unmanaged<NSArray>?
        let raw = unsafeBitCast(method_getImplementation(m), to: Copy.self)(client, sel)
        let ids = (raw?.takeRetainedValue() as? [NSNumber])?.map { $0.int64Value } ?? []
        if let builtIn = ids.first(where: { boolFor("isKeyboardBuiltIn:", cls, client, $0) == true }) {
            return builtIn
        }
        return ids.first
    }

    private static func boolFor(_ sel: String, _ cls: NSObject.Type, _ client: NSObject, _ kb: Int64) -> Bool? {
        let s = NSSelectorFromString(sel)
        guard let m = class_getInstanceMethod(cls, s) else { return nil }
        typealias F = @convention(c) (AnyObject, Selector, Int64) -> ObjCBool
        return unsafeBitCast(method_getImplementation(m), to: F.self)(client, s, kb).boolValue
    }

    private static func floatFor(_ sel: String, _ cls: NSObject.Type, _ client: NSObject, _ kb: Int64) -> Float? {
        let s = NSSelectorFromString(sel)
        guard let m = class_getInstanceMethod(cls, s) else { return nil }
        typealias F = @convention(c) (AnyObject, Selector, Int64) -> Float
        return unsafeBitCast(method_getImplementation(m), to: F.self)(client, s, kb)
    }

    private static func doubleFor(_ sel: String, _ cls: NSObject.Type, _ client: NSObject, _ kb: Int64) -> Double? {
        let s = NSSelectorFromString(sel)
        guard let m = class_getInstanceMethod(cls, s) else { return nil }
        typealias F = @convention(c) (AnyObject, Selector, Int64) -> Double
        return unsafeBitCast(method_getImplementation(m), to: F.self)(client, s, kb)
    }

    private static func setIdleDimTime(_ v: Double, _ cls: NSObject.Type, _ client: NSObject, _ kb: Int64) -> Bool? {
        let s = NSSelectorFromString("setIdleDimTime:forKeyboard:")
        guard let m = class_getInstanceMethod(cls, s) else { return nil }
        typealias F = @convention(c) (AnyObject, Selector, Double, Int64) -> ObjCBool
        return unsafeBitCast(method_getImplementation(m), to: F.self)(client, s, v, kb).boolValue
    }

    private static func setBrightness(_ v: Float, _ cls: NSObject.Type, _ client: NSObject, _ kb: Int64) -> Bool? {
        let s = NSSelectorFromString("setBrightness:forKeyboard:")
        guard let m = class_getInstanceMethod(cls, s) else { return nil }
        typealias F = @convention(c) (AnyObject, Selector, Float, Int64) -> ObjCBool
        return unsafeBitCast(method_getImplementation(m), to: F.self)(client, s, v, kb).boolValue
    }
}

/// Fallback when no backlight API is available — the app stays alive and no-ops.
/// (A future IOKit `AppleHIDKeyboardEventDriverV2` impl can slot in here behind
/// the same protocol; CoreBrightness is the validated primary today.)
final class UnavailableBacklight: BacklightController {
    var isAvailable: Bool { false }
    var isSuppressed: Bool { false }
    func currentLevel() -> Double? { nil }
    @discardableResult func setLevel(_ level: Double) -> Bool { false }
    func idleDimTime() -> Double? { nil }
    @discardableResult func setIdleDimTime(_ seconds: Double) -> Bool { false }
}

/// Pick the best available backlight controller.
func makeBacklightController() -> BacklightController {
    CoreBrightnessBacklight() ?? UnavailableBacklight()
}
