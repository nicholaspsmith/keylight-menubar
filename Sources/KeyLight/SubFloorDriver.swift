// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import CoreGraphics
import KeyLightCore

/// Keeps the keyboard backlight at a sub-floor level: runs `SubFloorHold`
/// against the live PWM and owns everything macOS would otherwise do to the
/// backlight while it is held.
///
/// While parked:
/// - the daemon's idle timeout is suspended and re-implemented here from the
///   user's own setting, so the hold is not fought and the keys still go dark;
/// - auto-brightness is off, so ambient light cannot retarget the daemon;
/// - a daemon level that is neither of the hold's two targets means someone
///   else set the backlight: the hold lets go and reports the new level;
/// - lid closed, system sleep and display sleep pause the hold.
/// All of it is undone on unpark or quit, and a crash leaves a record the next
/// launch uses to undo it.
final class SubFloorDriver {
    private let client: CoreBrightnessClient
    private let pwm: KeyboardPWM
    private let defaults: UserDefaults

    /// The held level, nil when not parked.
    private(set) var level: Double?
    /// Another app or Control Center changed the backlight; the hold has let go.
    var onExternalChange: ((Double) -> Void)?

    private var hold = SubFloorHold(targetTicks: 1)
    private var timer: Timer?
    private var systemAsleep = false
    private var displayAsleep = false
    private var wasPaused = false
    private var observers: [NSObjectProtocol] = []
    /// Auto-brightness as it was before parking, restored on unpark.
    private var savedAutoBrightness = false

    private static let floorLevel = Float(BacklightLadder.nativeFloor)
    private static let fastInterval: TimeInterval = 0.01
    private static let holdInterval: TimeInterval = 0.1
    private static let pausedInterval: TimeInterval = 1
    /// `kCGAnyInputEventType`: keys, clicks, pointer and scroll.
    private static let anyInput = CGEventType(rawValue: ~0)!

    init(client: CoreBrightnessClient, pwm: KeyboardPWM, defaults: UserDefaults = .standard) {
        self.client = client
        self.pwm = pwm
        self.defaults = defaults
    }

    var isParked: Bool { level != nil }
    var floorTicks: Double { pwm.floorTicks }
    var isPaused: Bool { systemAsleep || displayAsleep || Clamshell.isClosed }

    // MARK: - Park / unpark

    func park(level newLevel: Double) {
        log.info("park \(newLevel, privacy: .public)")
        let ticks = BacklightLadder.targetTicks(for: newLevel, floorTicks: pwm.floorTicks)
        if level == nil {
            savedAutoBrightness = client.isAutoBrightnessEnabled
            SubFloorStore.savePendingRestore(autoBrightness: savedAutoBrightness, to: defaults)
            if savedAutoBrightness { client.enableAutoBrightness(false) }
            client.suspendIdleDimming(true)
            // Commit the floor so the daemon's persisted level is ours: it is
            // what it restores after sleep or a lid close, and what the keys
            // show if KeyLight dies mid-hold.
            client.fade(to: Self.floorLevel, durationMs: SubFloorHold.approachDownMs, commit: true)
            hold = SubFloorHold(targetTicks: ticks, floorTicks: pwm.floorTicks, lastIssued: .floor)
            observeSystem()
        } else {
            hold.retarget(ticks: ticks)
        }
        level = newLevel
        SubFloorStore.saveParkedLevel(newLevel, to: defaults)
        schedule(after: 0)
    }

    /// Stop holding and put back everything parking changed. The caller then
    /// sets `nextLevel`. The daemon drops a set to the target it is already
    /// fading to, and the hold's last fade was to 0 or the floor, so a set to
    /// that same level is preceded by a slow fade the other way.
    func unpark(before nextLevel: Float) {
        guard level != nil else { return }
        log.info("unpark before \(nextLevel, privacy: .public)")
        let last = hold.lastIssued
        release()
        SubFloorStore.saveParkedLevel(nil, to: defaults)
        let same = (last == .off && nextLevel == 0) || (last == .floor && abs(nextLevel - Self.floorLevel) < 1e-6)
        if same, let last {
            client.fade(to: last == .off ? Self.floorLevel : 0, durationMs: SubFloorHold.slowMs, commit: false)
        }
    }

    /// Quit: leave the keys at the native floor and the daemon as it was. The
    /// held level stays saved for the next launch.
    func shutdown() {
        guard let held = level else { return }
        unpark(before: Self.floorLevel)
        SubFloorStore.saveParkedLevel(held, to: defaults)
        client.setBrightness(Self.floorLevel)
    }

    /// At launch: undo whatever a crash mid-hold left behind, then re-apply the
    /// level KeyLight was holding when it last quit. (A saved level exists
    /// only then: any other change of level clears it. The daemon's own level
    /// can't tell us whether someone changed it since, because quitting
    /// hands the keys back to auto-brightness, which moves it.)
    func restoreAfterLaunch() {
        if let auto = SubFloorStore.loadPendingRestore(from: defaults) {
            client.suspendIdleDimming(false)
            if auto { client.enableAutoBrightness(true) }
            client.setBrightness(Self.floorLevel) // also clears a persisted mute
            SubFloorStore.savePendingRestore(autoBrightness: nil, to: defaults)
        }
        if let saved = SubFloorStore.loadParkedLevel(from: defaults) {
            park(level: saved)
        }
    }

    private func release() {
        timer?.invalidate()
        timer = nil
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers = []
        // Only tracked while parked; a stale flag would start the next hold paused.
        systemAsleep = false
        displayAsleep = false
        wasPaused = false
        client.suspendIdleDimming(false)
        if savedAutoBrightness { client.enableAutoBrightness(true) }
        SubFloorStore.savePendingRestore(autoBrightness: nil, to: defaults)
        level = nil
    }

    // MARK: - The loop

    private func schedule(after interval: TimeInterval) {
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: false) { [weak self] _ in self?.tick() }
        // .common, so the hold keeps running while a menu is open.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard level != nil else { return }

        if isPaused {
            // The daemon owns the backlight while the lid is shut or the Mac
            // sleeps; start over from wherever it is on resume.
            wasPaused = true
            return schedule(after: Self.pausedInterval)
        }
        if wasPaused {
            wasPaused = false
            hold.retarget(ticks: hold.targetTicks)
        }

        // Every fade the hold sends targets 0 or the floor, so any other level
        // came from someone else.
        if let now = client.brightness(), !Self.isHoldTarget(now) {
            log.info("external change to \(now, privacy: .public)")
            let reapply = savedAutoBrightness
            release()
            SubFloorStore.saveParkedLevel(nil, to: defaults)
            // Turning auto-brightness back on recomputes the level from its
            // curve, discarding the change it never saw. Set it again with
            // auto-brightness on, as a user adjustment it learns from.
            if reapply { client.setBrightness(now) }
            onExternalChange?(Double(now))
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        let timeout = client.idleDimTime() ?? 0
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: Self.anyInput)
        if timeout > 0 && idle >= timeout {
            let fades = hold.goDark()
            if !fades.isEmpty { log.info("idle \(idle, privacy: .public) s >= \(timeout, privacy: .public) s: dark") }
            send(fades)
        } else {
            if hold.phase == .dark { log.info("input: relight") }
            hold.wake()
            send(hold.step(pwm: pwm.duty, now: now))
        }

        switch hold.phase {
        case .approaching, .closing, .holding(.floor):
            // Climbing reverses on a reading, so read often.
            schedule(after: Self.fastInterval)
        case .holding(.off):
            // Descending reverses by the clock: wake on time for it.
            let untilReverse = (hold.reverseAt ?? now) - now
            schedule(after: max(0.005, min(Self.holdInterval, untilReverse)))
        default:
            schedule(after: Self.holdInterval)
        }
    }

    private func send(_ fades: [SubFloorHold.Fade]) {
        for f in fades {
            client.fade(to: f.target == .off ? 0 : Self.floorLevel, durationMs: f.durationMs, commit: false)
        }
    }

    private static func isHoldTarget(_ level: Float) -> Bool {
        abs(level) < 1e-6 || abs(level - floorLevel) < 1e-6
    }

    // MARK: - Sleep and display sleep

    private func observeSystem() {
        let nc = NSWorkspace.shared.notificationCenter
        let pairs: [(Notification.Name, (SubFloorDriver) -> Void)] = [
            (NSWorkspace.willSleepNotification, { $0.systemAsleep = true }),
            (NSWorkspace.didWakeNotification, { $0.systemAsleep = false }),
            (NSWorkspace.screensDidSleepNotification, { $0.displayAsleep = true }),
            (NSWorkspace.screensDidWakeNotification, { $0.displayAsleep = false }),
        ]
        observers = pairs.map { name, apply in
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                apply(self)
                self.schedule(after: 0)
            }
        }
    }
}
