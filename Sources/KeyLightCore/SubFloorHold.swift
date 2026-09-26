// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

/// Holds the keyboard backlight PWM at a duty below macOS's floor.
///
/// CoreBrightness will not target any positive duty under its floor, but it
/// fades every change at about 60 Hz and passes through every duty on the
/// way. So the hold steers the fade: it alternates slow fades toward off and
/// toward the floor, reversing whenever the duty reaches the edge of a small
/// band around the target. Measured: 1–54 ticks held within ±1–2 ticks, about
/// one reversal every few seconds, no visible flicker.
///
/// Pure logic. Feed it the observed duty (0 when the PWM is disabled) and
/// issue the fades it returns, in order.
public struct SubFloorHold: Sendable {
    /// Where a fade heads. The daemon offers no other sub-floor targets.
    public enum Target: Sendable, Equatable { case off, floor }

    public struct Fade: Sendable, Equatable {
        public let target: Target
        public let durationMs: Int32
        public init(target: Target, durationMs: Int32) {
            self.target = target
            self.durationMs = durationMs
        }
    }

    public enum Phase: Sendable, Equatable {
        case approaching(Target)
        case holding(Target)
        /// Idle timeout: faded to off, waiting for `wake()`.
        case dark
    }

    /// The daemon's fade duration is milliseconds; about 32.8 s is the longest
    /// it honours, and larger values fade fast again.
    public static let slowMs: Int32 = 32767
    public static let approachDownMs: Int32 = 1500
    public static let approachUpMs: Int32 = 500
    /// Matches the daemon's own idle fade-out.
    public static let darkMs: Int32 = 500

    /// Switch from the fast approach to the slow hold this close to the band.
    static let approachMargin = 4.0
    /// Further than this outside the band while holding means something moved
    /// the duty (wake, a missed reversal): approach again.
    static let recoverMargin = 6.0

    public private(set) var targetTicks: Double
    public private(set) var phase: Phase?
    /// The last target sent, because the daemon drops a fade to the target it
    /// is already heading for.
    public private(set) var lastIssued: Target?

    public init(targetTicks: Double, lastIssued: Target? = nil) {
        self.targetTicks = max(1, targetTicks)
        self.lastIssued = lastIssued
    }

    private var halfBand: Double { max(1, (targetTicks * 0.05).rounded()) }
    public var lower: Double { max(1, targetTicks - halfBand) }
    public var upper: Double { targetTicks + halfBand }

    /// Hold a different duty from wherever the PWM is now.
    public mutating func retarget(ticks: Double) {
        targetTicks = max(1, ticks)
        phase = nil
    }

    public mutating func step(pwm: Int) -> [Fade] {
        let p = Double(pwm)
        switch phase {
        case nil:
            return begin(p)
        case .dark:
            return []
        case .approaching(.off):
            if pwm == 0 { return begin(p) }
            guard p <= upper + Self.approachMargin else { return [] }
            phase = .holding(.off)
            return issue(.off, Self.slowMs)
        case .approaching(.floor):
            guard p >= lower - Self.approachMargin else { return [] }
            phase = .holding(.floor)
            return issue(.floor, Self.slowMs)
        case .holding(.off):
            if pwm == 0 || p > upper + Self.recoverMargin { return begin(p) }
            guard p <= lower else { return [] }
            phase = .holding(.floor)
            return issue(.floor, Self.slowMs)
        case .holding(.floor):
            if pwm == 0 || p < lower - Self.recoverMargin { return begin(p) }
            guard p >= upper else { return [] }
            phase = .holding(.off)
            return issue(.off, Self.slowMs)
        }
    }

    /// Fade to off for the idle timeout. Returns nothing if already dark.
    public mutating func goDark() -> [Fade] {
        guard phase != .dark else { return [] }
        phase = .dark
        return issue(.off, Self.darkMs)
    }

    /// Input arrived after `goDark()`: the next `step` relights.
    public mutating func wake() {
        if phase == .dark { phase = nil }
    }

    private mutating func begin(_ p: Double) -> [Fade] {
        if p == 0 || p < lower {
            if p >= lower - Self.approachMargin {
                phase = .holding(.floor)
                return issue(.floor, Self.slowMs)
            }
            phase = .approaching(.floor)
            return issue(.floor, Self.approachUpMs)
        }
        if p > upper {
            if p <= upper + Self.approachMargin {
                phase = .holding(.off)
                return issue(.off, Self.slowMs)
            }
            phase = .approaching(.off)
            return issue(.off, Self.approachDownMs)
        }
        phase = .holding(.off)
        return issue(.off, Self.slowMs)
    }

    private mutating func issue(_ target: Target, _ ms: Int32) -> [Fade] {
        var fades: [Fade] = []
        if lastIssued == target {
            fades.append(Fade(target: target == .off ? .floor : .off, durationMs: Self.slowMs))
        }
        fades.append(Fade(target: target, durationMs: ms))
        lastIssued = target
        return fades
    }
}
