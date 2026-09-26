// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import Foundation
import ObjectiveC.runtime

/// Typed access to the private `CoreBrightness.KeyboardBrightnessClient`,
/// validated on macOS 26 / Apple Silicon. Private API has no Swift bridging
/// header, so each selector is called through its IMP cast to the exact C
/// signature its type encoding gives. The built-in keyboard id is discovered,
/// never hardcoded. Levels are the daemon's `0...1` brightness.
final class CoreBrightnessClient {
    private let cls: NSObject.Type
    private let client: NSObject
    private var keyboardID: UInt64

    init?() {
        let path = "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
        guard dlopen(path, RTLD_NOW) != nil,
              let cls = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type
        else { return nil }
        let client = cls.init()
        self.cls = cls
        self.client = client
        self.keyboardID = 0
        guard let id = builtInKeyboardID() else { return nil }
        self.keyboardID = id
    }

    // MARK: Level

    /// The daemon's current target level. While idle-dimmed or muted it reads 0.
    func brightness() -> Float? {
        guard let f = call("brightnessForKeyboard:", as: GetFloat.self, { $0(self.client, $1, self.keyboardID) }),
              f >= 0, f.isFinite else { return nil }
        return f
    }

    /// Committed set with the daemon's default fade (about 350 ms). Any
    /// positive value below 1/128 lights the floor.
    @discardableResult
    func setBrightness(_ level: Float) -> Bool {
        call("setBrightness:forKeyboard:", as: SetFloat.self, { $0(self.client, $1, level, self.keyboardID).boolValue }) ?? false
    }

    /// Set with an explicit fade. `durationMs` is the whole fade's length
    /// (0 = instant, about 32767 the longest honoured). `commit: false` skips
    /// persisting the manual level, but a set to 0 still flips the persisted
    /// Muted flag. A fade to the target already being faded to is ignored.
    @discardableResult
    func fade(to level: Float, durationMs: Int32, commit: Bool) -> Bool {
        call("setBrightness:fadeSpeed:commit:forKeyboard:", as: Fade.self, {
            $0(self.client, $1, level, durationMs, ObjCBool(commit), self.keyboardID).boolValue
        }) ?? false
    }

    // MARK: Idle timeout

    /// Seconds of inactivity before the daemon turns the backlight off; 0 = never.
    func idleDimTime() -> Double? {
        guard let d = call("idleDimTimeForKeyboard:", as: GetDouble.self, { $0(self.client, $1, self.keyboardID) }),
              d >= 0, d.isFinite else { return nil }
        return d
    }

    @discardableResult
    func setIdleDimTime(_ seconds: Double) -> Bool {
        guard seconds >= 0, seconds.isFinite else { return false }
        return call("setIdleDimTime:forKeyboard:", as: SetDouble.self, { $0(self.client, $1, seconds, self.keyboardID).boolValue }) ?? false
    }

    /// Stop (or resume) the daemon's own idle timeout without changing the
    /// stored setting.
    @discardableResult
    func suspendIdleDimming(_ suspend: Bool) -> Bool {
        call("suspendIdleDimming:forKeyboard:", as: SetBool.self, { $0(self.client, $1, ObjCBool(suspend), self.keyboardID).boolValue }) ?? false
    }

    // MARK: Auto-brightness and state

    var isAutoBrightnessEnabled: Bool { flag("isAutoBrightnessEnabledForKeyboard:") }

    @discardableResult
    func enableAutoBrightness(_ enable: Bool) -> Bool {
        call("enableAutoBrightness:forKeyboard:", as: SetBool.self, { $0(self.client, $1, ObjCBool(enable), self.keyboardID).boolValue }) ?? false
    }

    /// True while the daemon keeps the backlight dark: lid closed, idle
    /// timeout, or muted by a set to 0.
    var isSuppressed: Bool { flag("isBacklightSuppressedOnKeyboard:") }

    // MARK: - IMP plumbing

    private typealias GetBool = @convention(c) (AnyObject, Selector, UInt64) -> ObjCBool
    private typealias GetFloat = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias GetDouble = @convention(c) (AnyObject, Selector, UInt64) -> Double
    private typealias SetFloat = @convention(c) (AnyObject, Selector, Float, UInt64) -> ObjCBool
    private typealias SetDouble = @convention(c) (AnyObject, Selector, Double, UInt64) -> ObjCBool
    private typealias SetBool = @convention(c) (AnyObject, Selector, ObjCBool, UInt64) -> ObjCBool
    private typealias Fade = @convention(c) (AnyObject, Selector, Float, Int32, ObjCBool, UInt64) -> ObjCBool
    private typealias CopyIDs = @convention(c) (AnyObject, Selector) -> Unmanaged<NSArray>?

    private func call<F, R>(_ name: String, as _: F.Type, _ body: (F, Selector) -> R) -> R? {
        let sel = NSSelectorFromString(name)
        guard let m = class_getInstanceMethod(cls, sel) else { return nil }
        return body(unsafeBitCast(method_getImplementation(m), to: F.self), sel)
    }

    private func flag(_ name: String, keyboard: UInt64? = nil) -> Bool {
        let kb = keyboard ?? keyboardID
        return call(name, as: GetBool.self, { $0(self.client, $1, kb).boolValue }) ?? false
    }

    private func builtInKeyboardID() -> UInt64? {
        let raw = call("copyKeyboardBacklightIDs", as: CopyIDs.self, { $0(self.client, $1) }) ?? nil
        let ids = (raw?.takeRetainedValue() as? [NSNumber])?.map { $0.uint64Value } ?? []
        return ids.first { flag("isKeyboardBuiltIn:", keyboard: $0) } ?? ids.first
    }
}
