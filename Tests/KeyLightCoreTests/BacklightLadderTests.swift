// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
@testable import KeyLightCore

final class BacklightLadderTests: XCTestCase {
    private let floor = BacklightLadder.nativeFloor
    private let step = BacklightLadder.linearStep
    private func rung(_ ticks: Double) -> Double { ticks / 54 * floor }
    private func next(_ l: Double, _ d: Direction) -> Double { BacklightLadder.next(current: l, direction: d) }

    // Above 1/16: unchanged linear behaviour.
    func testUpAddsOneStep() { XCTAssertEqual(next(0.5, .up), 0.5625, accuracy: 1e-9) }
    func testDownSubtractsOneStep() { XCTAssertEqual(next(0.5, .down), 0.4375, accuracy: 1e-9) }
    func testUpClampsAtOne() { XCTAssertEqual(next(0.97, .up), 1.0, accuracy: 1e-9) }
    func testUpFromMaxStaysMax() { XCTAssertEqual(next(1.0, .up), 1.0, accuracy: 1e-9) }
    func testOffLadderStepsRelatively() { XCTAssertEqual(next(0.4346, .up), 0.4971, accuracy: 1e-9) }
    func testDownNeverSkipsBelowOneSixteenth() { XCTAssertEqual(next(0.1, .down), step, accuracy: 1e-9) }

    // At and below 1/16: the fixed ladder.
    func testFullDownwardLadder() {
        var l = step
        var seen: [Double] = []
        while l > 0 { l = next(l, .down); seen.append(l) }
        let expected = [floor] + [36, 24, 16, 11, 7, 4, 2, 1].map(rung) + [0]
        XCTAssertEqual(seen.count, expected.count)
        for (a, b) in zip(seen, expected) { XCTAssertEqual(a, b, accuracy: 1e-12) }
    }

    func testFullUpwardLadderIsTheMirror() {
        var l = 0.0
        var seen: [Double] = []
        while l < step { l = next(l, .up); seen.append(l) }
        let expected = [1, 2, 4, 7, 11, 16, 24, 36].map(rung) + [floor, step]
        XCTAssertEqual(seen.count, expected.count)
        for (a, b) in zip(seen, expected) { XCTAssertEqual(a, b, accuracy: 1e-12) }
    }

    func testNineStepsBelowOneSixteenth() {
        XCTAssertEqual(BacklightLadder.subFloorLevels.count + 1, 9)
    }

    func testDownFromZeroStaysZero() { XCTAssertEqual(next(0, .down), 0) }
    func testAutoBrightnessValueBelowOneSixteenthGoesToFloorOrUp() {
        XCTAssertEqual(next(0.056, .down), floor, accuracy: 1e-12)
        XCTAssertEqual(next(0.056, .up), step, accuracy: 1e-12)
    }
    func testOffRungSubFloorValueSnapsToNeighbours() {
        let between = rung(20)
        XCTAssertEqual(next(between, .up), rung(24), accuracy: 1e-12)
        XCTAssertEqual(next(between, .down), rung(16), accuracy: 1e-12)
    }
    func testFloatReadbackOfARungStillSteps() {
        let fromFloat = Double(Float(rung(4)))
        XCTAssertEqual(next(fromFloat, .down), rung(2), accuracy: 1e-12)
        XCTAssertEqual(next(fromFloat, .up), rung(7), accuracy: 1e-12)
    }

    // Classification and conversions.
    func testIsSubFloor() {
        XCTAssertFalse(BacklightLadder.isSubFloor(0))
        XCTAssertTrue(BacklightLadder.isSubFloor(rung(1)))
        XCTAssertTrue(BacklightLadder.isSubFloor(rung(36)))
        XCTAssertFalse(BacklightLadder.isSubFloor(floor))
        XCTAssertFalse(BacklightLadder.isSubFloor(Double(Float(floor))))
    }
    func testTargetTicks() {
        XCTAssertEqual(BacklightLadder.targetTicks(for: rung(36), floorTicks: 54), 36)
        XCTAssertEqual(BacklightLadder.targetTicks(for: rung(1), floorTicks: 54), 1)
        XCTAssertEqual(BacklightLadder.targetTicks(for: rung(1), floorTicks: 70), 1, "bottom rung is always 1 tick")
        XCTAssertEqual(BacklightLadder.targetTicks(for: 1e-9, floorTicks: 54), 1, "never below 1 tick")
    }
    func testDisplayFractionKeepsTheFirstRayLit() {
        XCTAssertEqual(BacklightLadder.displayFraction(0), 0)
        XCTAssertEqual(BacklightLadder.displayFraction(rung(1)), 0.01)
        XCTAssertEqual(BacklightLadder.displayFraction(0.5), 0.5)
    }
    func testPercentLabel() {
        XCTAssertEqual(BacklightLadder.percentLabel(0), "0%")
        XCTAssertEqual(BacklightLadder.percentLabel(rung(1)), "<1%")
        XCTAssertEqual(BacklightLadder.percentLabel(floor), "1%")
        XCTAssertEqual(BacklightLadder.percentLabel(0.5), "50%")
    }
}
