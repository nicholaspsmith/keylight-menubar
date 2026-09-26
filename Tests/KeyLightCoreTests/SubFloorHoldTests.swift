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

    func testBand() {
        let a = SubFloorHold(targetTicks: 36)
        XCTAssertEqual(a.lower, 34); XCTAssertEqual(a.upper, 38)
        let b = SubFloorHold(targetTicks: 1)
        XCTAssertEqual(b.lower, 1); XCTAssertEqual(b.upper, 2)
        let c = SubFloorHold(targetTicks: 11)
        XCTAssertEqual(c.lower, 10); XCTAssertEqual(c.upper, 12)
    }

    func testApproachDownFromFloorThenSlowHoldWithNudge() {
        var h = SubFloorHold(targetTicks: 11)
        XCTAssertEqual(h.step(pwm: 54), [Fade(target: .off, durationMs: SubFloorHold.approachDownMs)])
        XCTAssertEqual(h.phase, .approaching(.off))
        XCTAssertEqual(h.step(pwm: 30), [])
        // Within 4 of the band's top: slow down toward off. Same target, so nudge first.
        XCTAssertEqual(h.step(pwm: 16), [Fade(target: .floor, durationMs: slow), Fade(target: .off, durationMs: slow)])
        XCTAssertEqual(h.phase, .holding(.off))
    }

    func testReversesAtBandEdges() {
        var h = SubFloorHold(targetTicks: 11)
        _ = h.step(pwm: 11) // in band: start holding downward
        XCTAssertEqual(h.phase, .holding(.off))
        XCTAssertEqual(h.step(pwm: 11), [])
        XCTAssertEqual(h.step(pwm: 10), [Fade(target: .floor, durationMs: slow)])
        XCTAssertEqual(h.phase, .holding(.floor))
        XCTAssertEqual(h.step(pwm: 11), [])
        XCTAssertEqual(h.step(pwm: 12), [Fade(target: .off, durationMs: slow)])
        XCTAssertEqual(h.phase, .holding(.off))
    }

    func testApproachUpFromOff() {
        var h = SubFloorHold(targetTicks: 36, lastIssued: .off)
        XCTAssertEqual(h.step(pwm: 0), [Fade(target: .floor, durationMs: SubFloorHold.approachUpMs)])
        XCTAssertEqual(h.step(pwm: 20), [])
        XCTAssertEqual(h.step(pwm: 31), [Fade(target: .off, durationMs: slow), Fade(target: .floor, durationMs: slow)])
        XCTAssertEqual(h.phase, .holding(.floor))
    }

    func testCloseBelowStartsSlowUpDirectly() {
        var h = SubFloorHold(targetTicks: 1, lastIssued: .off)
        XCTAssertEqual(h.step(pwm: 0), [Fade(target: .floor, durationMs: slow)])
        XCTAssertEqual(h.phase, .holding(.floor))
    }

    func testDisabledPWMWhileHoldingRestartsApproach() {
        var h = SubFloorHold(targetTicks: 11)
        _ = h.step(pwm: 11)
        XCTAssertEqual(h.step(pwm: 0), [Fade(target: .floor, durationMs: SubFloorHold.approachUpMs)])
        XCTAssertEqual(h.phase, .approaching(.floor))
    }

    func testFarAboveWhileHoldingRestartsApproachWithNudge() {
        var h = SubFloorHold(targetTicks: 11)
        _ = h.step(pwm: 11) // holding(.off), last issued .off
        XCTAssertEqual(h.step(pwm: 30), [Fade(target: .floor, durationMs: slow), Fade(target: .off, durationMs: SubFloorHold.approachDownMs)])
        XCTAssertEqual(h.phase, .approaching(.off))
    }

    func testFarBelowWhileHoldingUpRestartsApproach() {
        var h = SubFloorHold(targetTicks: 36)
        _ = h.step(pwm: 36); _ = h.step(pwm: 34) // holding(.floor)
        XCTAssertEqual(h.phase, .holding(.floor))
        XCTAssertEqual(h.step(pwm: 20), [Fade(target: .off, durationMs: slow), Fade(target: .floor, durationMs: SubFloorHold.approachUpMs)])
    }

    func testDarkAndWake() {
        var h = SubFloorHold(targetTicks: 7)
        _ = h.step(pwm: 7)
        XCTAssertEqual(h.goDark(), [Fade(target: .floor, durationMs: slow), Fade(target: .off, durationMs: SubFloorHold.darkMs)])
        XCTAssertEqual(h.phase, .dark)
        XCTAssertEqual(h.step(pwm: 3), [], "dark ignores the PWM")
        XCTAssertEqual(h.goDark(), [], "already dark")
        h.wake()
        XCTAssertEqual(h.step(pwm: 0), [Fade(target: .floor, durationMs: SubFloorHold.approachUpMs)])
    }

    func testRetargetKeepsLastIssued() {
        var h = SubFloorHold(targetTicks: 11)
        _ = h.step(pwm: 11) // last issued .off
        h.retarget(ticks: 4)
        XCTAssertNil(h.phase)
        XCTAssertEqual(h.step(pwm: 11), [Fade(target: .floor, durationMs: slow), Fade(target: .off, durationMs: SubFloorHold.approachDownMs)])
    }
}
