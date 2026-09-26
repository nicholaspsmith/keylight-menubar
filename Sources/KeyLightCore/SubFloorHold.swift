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
/// toward the floor, keeping the fade's value on the target.
///
/// The PWM register shows the fade's value rounded, so a reading of T means
/// the value is in `T-0.5 ..< T+0.5`. Going up, the hold reverses the moment
/// the reading becomes T+1 (the value just crossed T+0.5). Going down, the
/// reading changes too late to act on (at T-0.5, and below 0.5 the LEDs go
/// dark), so it reverses by dead reckoning: the fade's speed is known, so it
/// descends `descentTicks` by the clock and turns back. The value stays in
/// `T+0.5-descentTicks ..< T+0.5`, which reads T. Measured on the old
/// integer band: the bottom rung read 2 ticks 99% of the time.
///
/// Pure logic. Feed it the observed duty (0 when the PWM is disabled) and a
/// monotonic clock, and issue the fades it returns, in order.
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
        /// Far from the target: a fast fade.
        case approaching(Target)
        /// Near the target: a fade at `closingRate`, slow enough to stop on
        /// one tick.
        case closing(Target)
        /// On the target: slow fades, reversing as described above.
        case holding(Target)
        /// Idle timeout: faded to off, waiting for `wake()`.
        case dark
    }

    /// The daemon's fade duration is milliseconds, for the whole fade: its
    /// speed is distance ÷ duration. About 32.8 s is the longest it honours;
    /// larger values fade fast again.
    public static let slowMs: Int32 = 32767
    public static let approachDownMs: Int32 = 1500
    public static let approachUpMs: Int32 = 500
    /// Matches the daemon's own idle fade-out.
    public static let darkMs: Int32 = 500
    /// Ticks per second while closing on the target: fast enough to finish a
    /// step in about a second, slow enough to stop within a tick.
    public static let closingRate = 20.0
    /// Distance from the target at which the fast approach hands over to closing.
    public static let closingDistance = 20.0
    /// The slowest descent while holding, in ticks per second. Slower means
    /// fewer reversals (each flips a daemon preference); the upward leg is
    /// fixed by the daemon's longest fade.
    public static let holdDescentRate = 0.2
    /// Further than this from the target while holding means something moved
    /// the duty (wake, a missed reversal): approach again.
    static let recoverMargin = 6.0

    public private(set) var targetTicks: Double
    /// The native floor in ticks: where a fade toward `.floor` ends.
    public let floorTicks: Double
    public private(set) var phase: Phase?
    /// The last target sent, because the daemon drops a fade to the target it
    /// is already heading for.
    public private(set) var lastIssued: Target?
    /// While descending in the hold: when to turn back up.
    public private(set) var reverseAt: Double?

    public init(targetTicks: Double, floorTicks: Double = 54, lastIssued: Target? = nil) {
        self.targetTicks = max(1, targetTicks)
        self.floorTicks = floorTicks
        self.lastIssued = lastIssued
    }

    /// How far below T+0.5 each descent goes: at least 0.8 of a tick (so the
    /// value never nears T-0.5), and ±5% of larger targets to space out
    /// reversals.
    public var descentTicks: Double { max(0.8, targetTicks * 0.05) }

    /// The descent's fade: toward off from T+0.5 at `holdDescentRate`, or
    /// faster where the daemon's longest fade forces it.
    public var descentFade: (durationMs: Int32, seconds: Double) {
        let start = targetTicks + 0.5
        let ms = min(Double(Self.slowMs), (start / Self.holdDescentRate * 1000).rounded())
        let rate = start / (ms / 1000)
        return (Int32(ms), descentTicks / rate)
    }

    /// Hold a different duty from wherever the PWM is now.
    public mutating func retarget(ticks: Double) {
        targetTicks = max(1, ticks)
        phase = nil
        reverseAt = nil
    }

    public mutating func step(pwm: Int, now: Double) -> [Fade] {
        let p = Double(pwm)
        let t = targetTicks
        switch phase {
        case nil:
            return begin(p, now: now)
        case .dark:
            return []
        case .approaching(.off):
            if pwm == 0 { return begin(p, now: now) }
            guard p - t <= Self.closingDistance else { return [] }
            return close(.off, from: p)
        case .approaching(.floor):
            guard t - p <= Self.closingDistance else { return [] }
            return close(.floor, from: p)
        case .closing(.off):
            if pwm == 0 { return begin(p, now: now) }
            guard p <= t else { return [] }
            // The fast descent overshoots by up to a poll's worth; a slow
            // climb to T+0.5 gives the timed descent a clean start.
            phase = .holding(.floor)
            return issue(.floor, Self.slowMs)
        case .closing(.floor):
            guard p >= t else { return [] }
            phase = .holding(.floor)
            return issue(.floor, Self.slowMs)
        case .holding(.off):
            if pwm == 0 || p > t + 1 + Self.recoverMargin { return begin(p, now: now) }
            guard let at = reverseAt, now >= at else { return [] }
            reverseAt = nil
            phase = .holding(.floor)
            return issue(.floor, Self.slowMs)
        case .holding(.floor):
            if pwm == 0 || p < t - Self.recoverMargin { return begin(p, now: now) }
            guard p >= t + 1 else { return [] }
            return descend(now: now)
        }
    }

    /// Fade to off for the idle timeout. Returns nothing if already dark.
    public mutating func goDark() -> [Fade] {
        guard phase != .dark else { return [] }
        phase = .dark
        reverseAt = nil
        return issue(.off, Self.darkMs)
    }

    /// Input arrived after `goDark()`: the next `step` relights.
    public mutating func wake() {
        if phase == .dark { phase = nil }
    }

    private mutating func begin(_ p: Double, now: Double) -> [Fade] {
        reverseAt = nil
        let t = targetTicks
        if p < t {
            guard t - p > Self.closingDistance else { return close(.floor, from: p) }
            phase = .approaching(.floor)
            return issue(.floor, Self.approachUpMs)
        }
        if p > t {
            guard p - t > Self.closingDistance else { return close(.off, from: p) }
            phase = .approaching(.off)
            return issue(.off, Self.approachDownMs)
        }
        // Reading T: the value is somewhere in T±0.5. Go up to the edge
        // first, so the descent's clock starts from a known value.
        phase = .holding(.floor)
        return issue(.floor, Self.slowMs)
    }

    /// The reading just became T from above, so the value is T+0.5: start the
    /// timed descent.
    private mutating func descend(now: Double) -> [Fade] {
        let fade = descentFade
        phase = .holding(.off)
        reverseAt = now + fade.seconds
        return issue(.off, fade.durationMs)
    }

    /// A fade toward `target` that moves at `closingRate` from duty `p`.
    private mutating func close(_ target: Target, from p: Double) -> [Fade] {
        phase = .closing(target)
        let distance = target == .off ? p : max(0, floorTicks - p)
        let ms = (distance / Self.closingRate * 1000).rounded()
        return issue(target, Int32(min(Double(Self.slowMs), max(50, ms))))
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
