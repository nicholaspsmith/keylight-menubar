// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

/// Makes a KeyLight adjustment count as activity for the idle timeout.
///
/// The daemon turns the backlight off after the inactivity timeout and
/// ignores level sets until input it recognises arrives, so a slider drag or
/// hotkey after the lid opens changed nothing. Adjusting now suspends the
/// daemon's idle dimming (which relights the keys at once) and resumes it
/// only after the timeout passes with no input of any kind.
public struct AdjustWake {
    /// True while the daemon's idle dimming is suspended on our behalf.
    public private(set) var isHolding = false

    public init() {}

    /// A KeyLight adjustment. True when idle dimming should be suspended now.
    @discardableResult
    public mutating func userAdjusted(lidClosed: Bool) -> Bool {
        // The daemon owns a shut lid; no light shows anyway.
        guard !lidClosed, !isHolding else { return false }
        isHolding = true
        return true
    }

    /// Poll while holding. True when idle dimming should be resumed now.
    public mutating func tick(idleSeconds: Double, timeout: Double, lidClosed: Bool) -> Bool {
        guard isHolding else { return false }
        guard lidClosed || timeout <= 0 || idleSeconds >= timeout else { return false }
        isHolding = false
        return true
    }

    /// Stop holding without resuming: someone else now owns idle dimming.
    public mutating func cancel() { isHolding = false }
}
