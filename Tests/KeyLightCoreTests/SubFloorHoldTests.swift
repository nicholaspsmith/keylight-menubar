// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
@testable import KeyLightCore

final class SubFloorHoldTests: XCTestCase {
    typealias Fade = SubFloorHold.Fade
    private let slow = SubFloorHold.slowMs
    private func closing(_ distance: Double) -> Int32 { Int32(max(50, (distance / SubFloorHold.closingRate * 1000).rounded())) }

    func testDescentForTheBottomRung() {
        let h = SubFloorHold(targetTicks: 1)
        XCTAssertEqual(h.descentTicks, 0.8)
        // From 1.5 at 0.2 ticks/s: a 7.5 s fade, turned back after 4 s.
        XCTAssertEqual(h.descentFade.durationMs, 7500)
        XCTAssertEqual(h.descentFade.seconds, 4.0, accuracy: 1e-9)
    }

    func testDescentForAHighRungIsCappedByTheLongestFade() {
        let h = SubFloorHold(targetTicks: 36)
        XCTAssertEqual(h.descentTicks, 1.8, accuracy: 1e-9)
        XCTAssertEqual(h.descentFade.durationMs, slow)
        XCTAssertEqual(h.descentFade.seconds, 1.8 / (36.5 / 32.767), accuracy: 1e-6)
    }

    func testFarAboveApproachesFastThenClosesThenHolds() {
        var h = SubFloorHold(targetTicks: 4)
        XCTAssertEqual(h.step(pwm: 69, now: 0), [Fade(target: .off, durationMs: SubFloorHold.approachDownMs)])
        XCTAssertEqual(h.phase, .approaching(.off))
        XCTAssertEqual(h.step(pwm: 30, now: 0.1), [])
        // Within 20 of the target: close at 20 ticks/s. Same target, so nudge first.
        XCTAssertEqual(h.step(pwm: 24, now: 0.2), [Fade(target: .floor, durationMs: slow), Fade(target: .off, durationMs: closing(24))])
        XCTAssertEqual(h.phase, .closing(.off))
        XCTAssertEqual(h.step(pwm: 5, now: 1.0), [])
        // Reached the target: climb slowly to T+0.5 for a clean start.
        XCTAssertEqual(h.step(pwm: 4, now: 1.1), [Fade(target: .floor, durationMs: slow)])
        XCTAssertEqual(h.phase, .holding(.floor))
    }

    func testHoldCycle() {
        var h = SubFloorHold(targetTicks: 1, lastIssued: .floor)
        XCTAssertEqual(h.step(pwm: 1, now: 0), [Fade(target: .off, durationMs: slow), Fade(target: .floor, durationMs: slow)])
        XCTAssertEqual(h.phase, .holding(.floor))
        XCTAssertEqual(h.step(pwm: 1, now: 0.2), [])
        // Reading T+1: the value is T+0.5. Descend by the clock.
        XCTAssertEqual(h.step(pwm: 2, now: 0.3), [Fade(target: .off, durationMs: 7500)])
        XCTAssertEqual(h.phase, .holding(.off))
        XCTAssertEqual(h.reverseAt ?? -1, 4.3, accuracy: 1e-9)
        XCTAssertEqual(h.step(pwm: 1, now: 4.2), [])
        XCTAssertEqual(h.step(pwm: 1, now: 4.3), [Fade(target: .floor, durationMs: slow)])
        XCTAssertEqual(h.phase, .holding(.floor))
        XCTAssertNil(h.reverseAt)
        XCTAssertEqual(h.step(pwm: 2, now: 4.8), [Fade(target: .off, durationMs: 7500)])
    }

    func testNearAboveClosesDirectly() {
        var h = SubFloorHold(targetTicks: 36, lastIssued: .floor)
        XCTAssertEqual(h.step(pwm: 54, now: 0), [Fade(target: .off, durationMs: closing(54))])
        XCTAssertEqual(h.phase, .closing(.off))
    }

    func testFarBelowApproachesUpFastThenClosesThenHolds() {
        var h = SubFloorHold(targetTicks: 36, lastIssued: .off)
        XCTAssertEqual(h.step(pwm: 0, now: 0), [Fade(target: .floor, durationMs: SubFloorHold.approachUpMs)])
        XCTAssertEqual(h.phase, .approaching(.floor))
        XCTAssertEqual(h.step(pwm: 10, now: 0.1), [])
        XCTAssertEqual(h.step(pwm: 16, now: 0.2), [Fade(target: .off, durationMs: slow), Fade(target: .floor, durationMs: closing(54 - 16))])
        XCTAssertEqual(h.phase, .closing(.floor))
        XCTAssertEqual(h.step(pwm: 36, now: 1.2), [Fade(target: .off, durationMs: slow), Fade(target: .floor, durationMs: slow)])
        XCTAssertEqual(h.phase, .holding(.floor))
    }

    func testFromOffToOneTickClosesUpGently() {
        var h = SubFloorHold(targetTicks: 1, lastIssued: .off)
        XCTAssertEqual(h.step(pwm: 0, now: 0), [Fade(target: .floor, durationMs: closing(54))])
        XCTAssertEqual(h.phase, .closing(.floor))
        XCTAssertEqual(h.step(pwm: 1, now: 0.1), [Fade(target: .off, durationMs: slow), Fade(target: .floor, durationMs: slow)])
        XCTAssertEqual(h.phase, .holding(.floor))
    }

    func testClosingUsesFloorTicksForUpwardDistance() {
        var h = SubFloorHold(targetTicks: 30, floorTicks: 108, lastIssued: .off)
        XCTAssertEqual(h.step(pwm: 20, now: 0), [Fade(target: .floor, durationMs: closing(88))])
    }

    func testDisabledPWMWhileHoldingRestartsFromBelow() {
        var h = SubFloorHold(targetTicks: 11, lastIssued: .floor)
        _ = h.step(pwm: 11, now: 0); _ = h.step(pwm: 12, now: 0.1) // descending
        XCTAssertEqual(h.step(pwm: 0, now: 0.2), [Fade(target: .floor, durationMs: closing(54))])
        XCTAssertEqual(h.phase, .closing(.floor))
    }

    func testFarAboveWhileHoldingRestarts() {
        var h = SubFloorHold(targetTicks: 11, lastIssued: .floor)
        _ = h.step(pwm: 11, now: 0); _ = h.step(pwm: 12, now: 0.1) // holding(.off), last issued .off
        XCTAssertEqual(h.step(pwm: 40, now: 0.2), [Fade(target: .floor, durationMs: slow), Fade(target: .off, durationMs: SubFloorHold.approachDownMs)])
        XCTAssertEqual(h.phase, .approaching(.off))
        XCTAssertNil(h.reverseAt)
    }

    func testFarBelowWhileHoldingUpRestarts() {
        var h = SubFloorHold(targetTicks: 36, lastIssued: .off)
        _ = h.step(pwm: 36, now: 0) // holding(.floor)
        XCTAssertEqual(h.phase, .holding(.floor))
        XCTAssertEqual(h.step(pwm: 20, now: 0.1), [Fade(target: .off, durationMs: slow), Fade(target: .floor, durationMs: closing(34))])
        XCTAssertEqual(h.phase, .closing(.floor))
    }

    func testDarkAndWake() {
        var h = SubFloorHold(targetTicks: 7, lastIssued: .floor)
        _ = h.step(pwm: 7, now: 0); _ = h.step(pwm: 8, now: 0.1) // descending
        XCTAssertEqual(h.goDark(), [Fade(target: .floor, durationMs: slow), Fade(target: .off, durationMs: SubFloorHold.darkMs)])
        XCTAssertEqual(h.phase, .dark)
        XCTAssertNil(h.reverseAt)
        XCTAssertEqual(h.step(pwm: 3, now: 10), [], "dark ignores the PWM")
        XCTAssertEqual(h.goDark(), [], "already dark")
        h.wake()
        XCTAssertEqual(h.step(pwm: 0, now: 11), [Fade(target: .floor, durationMs: closing(54))])
    }

    func testRetargetKeepsLastIssued() {
        var h = SubFloorHold(targetTicks: 11, lastIssued: .floor)
        _ = h.step(pwm: 11, now: 0); _ = h.step(pwm: 12, now: 0.1) // last issued .off
        h.retarget(ticks: 4)
        XCTAssertNil(h.phase)
        XCTAssertNil(h.reverseAt)
        XCTAssertEqual(h.step(pwm: 11, now: 0.2), [Fade(target: .floor, durationMs: slow), Fade(target: .off, durationMs: closing(11))])
    }
}
