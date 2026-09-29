// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import CoreGraphics
import Foundation
import KeyLightCore

/// Reads and writes the keyboard backlight level (`0...1`). Levels below
/// `BacklightLadder.nativeFloor` are sub-floor duties KeyLight holds itself.
protocol BacklightController: AnyObject {
    var isAvailable: Bool { get }
    /// True when KeyLight can hold levels below macOS's floor on this Mac.
    var supportsSubFloor: Bool { get }
    /// True when the backlight is currently suppressed (e.g. clamshell / lid
    /// closed). Sets are accepted but no-op while suppressed.
    var isSuppressed: Bool { get }
    func currentLevel() -> Double?
    @discardableResult func setLevel(_ level: Double) -> Bool
    /// Seconds of inactivity before the backlight turns off; 0 = never.
    /// The same setting as System Settings ▸ Keyboard's inactivity timeout.
    func idleDimTime() -> Double?
    @discardableResult func setIdleDimTime(_ seconds: Double) -> Bool
    /// Something other than `setLevel` changed the level (Control Center,
    /// another app) while a sub-floor level was held.
    var onExternalChange: (() -> Void)? { get set }
    /// Clean up after a crash and re-apply a held level. Call once at launch.
    func restoreAfterLaunch()
    /// Leave the backlight and the daemon settled. Call at quit.
    func shutdown()
}

/// CoreBrightness for native levels, `SubFloorDriver` below the floor.
final class CoreBrightnessBacklight: BacklightController {
    private let client: CoreBrightnessClient
    private let driver: SubFloorDriver?
    private var wake = AdjustWake()
    private var wakeTimer: Timer?

    var onExternalChange: (() -> Void)?

    init?() {
        guard let client = CoreBrightnessClient() else { return nil }
        self.client = client
        driver = KeyboardPWM().map { SubFloorDriver(client: client, pwm: $0) }
        driver?.onExternalChange = { [weak self] _ in self?.onExternalChange?() }
    }

    var isAvailable: Bool { true }
    var supportsSubFloor: Bool { driver != nil }

    var isSuppressed: Bool {
        // While holding, the daemon's own flag is true during every fade
        // toward off, so only the lid counts.
        if driver?.isParked == true { return Clamshell.isClosed }
        return client.isSuppressed
    }

    func currentLevel() -> Double? {
        if let held = driver?.level { return held }
        guard let f = client.brightness() else { return nil }
        // Another app may have asked for less than the floor; the keys show
        // the floor, so report that.
        return f > 0 ? max(Double(f), BacklightLadder.nativeFloor) : 0
    }

    @discardableResult
    func setLevel(_ level: Double) -> Bool {
        let v = min(1.0, max(0.0, level))
        if BacklightLadder.isSubFloor(v), let driver {
            // The driver suspends idle dimming and runs the timeout itself.
            stopWake()
            driver.park(level: v)
            return true
        }
        driver?.unpark(before: Float(v))
        if wake.userAdjusted(lidClosed: Clamshell.isClosed) {
            // The suspension outlives this process; the record lets the next
            // launch undo it after a crash.
            UserDefaults.standard.set(true, forKey: Self.wakeSuspendedKey)
            client.suspendIdleDimming(true)
            startWakeTimer()
        }
        return client.setBrightness(Float(v))
    }

    // MARK: - Adjusting counts as activity

    private func startWakeTimer() {
        wakeTimer?.invalidate()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.wakeTick() }
        // .common, so it keeps running while the menu's slider is dragged.
        RunLoop.main.add(t, forMode: .common)
        wakeTimer = t
    }

    private func wakeTick() {
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        if wake.tick(idleSeconds: idle, timeout: client.idleDimTime() ?? 0, lidClosed: Clamshell.isClosed) {
            resumeIdleDimming()
            wakeTimer?.invalidate()
            wakeTimer = nil
        }
    }

    private static let wakeSuspendedKey = "adjustWakeSuspendedIdleDimming"

    private func resumeIdleDimming() {
        client.suspendIdleDimming(false)
        UserDefaults.standard.removeObject(forKey: Self.wakeSuspendedKey)
    }

    /// Drop the hold without resuming: the sub-floor driver owns idle dimming now.
    private func stopWake() {
        // The driver keeps its own crash record for the suspension it inherits.
        if wake.isHolding { UserDefaults.standard.removeObject(forKey: Self.wakeSuspendedKey) }
        wake.cancel()
        wakeTimer?.invalidate()
        wakeTimer = nil
    }

    func idleDimTime() -> Double? { client.idleDimTime() }

    @discardableResult
    func setIdleDimTime(_ seconds: Double) -> Bool { client.setIdleDimTime(seconds) }

    func restoreAfterLaunch() {
        if UserDefaults.standard.bool(forKey: Self.wakeSuspendedKey) { resumeIdleDimming() }
        driver?.restoreAfterLaunch()
    }
    func shutdown() {
        if wake.isHolding { resumeIdleDimming() }
        stopWake()
        driver?.shutdown()
    }
}

/// Fallback when no backlight API is available — the app stays alive and no-ops.
final class UnavailableBacklight: BacklightController {
    var isAvailable: Bool { false }
    var supportsSubFloor: Bool { false }
    var isSuppressed: Bool { false }
    var onExternalChange: (() -> Void)?
    func currentLevel() -> Double? { nil }
    @discardableResult func setLevel(_ level: Double) -> Bool { false }
    func idleDimTime() -> Double? { nil }
    @discardableResult func setIdleDimTime(_ seconds: Double) -> Bool { false }
    func restoreAfterLaunch() {}
    func shutdown() {}
}

/// Pick the best available backlight controller.
func makeBacklightController() -> BacklightController {
    CoreBrightnessBacklight() ?? UnavailableBacklight()
}
