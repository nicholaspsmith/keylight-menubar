import XCTest
@testable import KeyLightCore

final class LevelMathTests: XCTestCase {
    private func up(_ v: Double) -> Double { LevelMath.nextLevel(current: v, direction: .up) }
    private func down(_ v: Double) -> Double { LevelMath.nextLevel(current: v, direction: .down) }

    // MARK: Sixteenths range (native feel above 1/16)

    func testUpAddsOneSixteenth() {
        XCTAssertEqual(up(0.5), 0.5625, accuracy: 1e-9)
    }

    func testDownSubtractsOneSixteenth() {
        XCTAssertEqual(down(0.5), 0.4375, accuracy: 1e-9)
    }

    func testUpClampsAtOne() {
        XCTAssertEqual(up(0.97), 1.0, accuracy: 1e-9)
    }

    func testUpFromMaxStaysMax() {
        XCTAssertEqual(up(1.0), 1.0, accuracy: 1e-9)
    }

    // MARK: Low-end tail (halvings down to the hardware floor)

    func testDownFromOneSixteenthGoesToOneThirtySecond() {
        XCTAssertEqual(down(1.0 / 16), 1.0 / 32, accuracy: 1e-9)
    }

    func testDownFromOneThirtySecondGoesToOneSixtyFourth() {
        XCTAssertEqual(down(1.0 / 32), 1.0 / 64, accuracy: 1e-9)
    }

    func testDownFromOneSixtyFourthGoesToFloor() {
        XCTAssertEqual(down(1.0 / 64), 1.0 / 128, accuracy: 1e-9)
    }

    func testDownFromFloorTurnsOff() {
        XCTAssertEqual(down(1.0 / 128), 0.0, accuracy: 1e-9)
    }

    func testDownFromOffStaysOff() {
        XCTAssertEqual(down(0.0), 0.0, accuracy: 1e-9)
    }

    func testUpFromOffGoesToFloor() {
        XCTAssertEqual(up(0.0), 1.0 / 128, accuracy: 1e-9)
    }

    func testUpFromOneThirtySecondGoesToOneSixteenth() {
        XCTAssertEqual(up(1.0 / 32), 1.0 / 16, accuracy: 1e-9)
    }

    // MARK: Off-ladder levels (auto-brightness sets arbitrary values)

    func testDownFromOffLadderSnapsToNextRungBelow() {
        XCTAssertEqual(down(0.056), 1.0 / 32, accuracy: 1e-9)
    }

    func testUpFromOffLadderSnapsToNextRungAbove() {
        XCTAssertEqual(up(0.056), 1.0 / 16, accuracy: 1e-9)
    }

    // MARK: Float readback noise must not stall a rung

    func testUpFromRungWithFloatNoiseAdvances() {
        // The controller reads back a Float; a hair above a rung still counts as that rung.
        XCTAssertEqual(up(0.5 + 1e-8), 0.5625, accuracy: 1e-9)
    }

    func testDownFromRungWithFloatNoiseRetreats() {
        XCTAssertEqual(down(0.5 - 1e-8), 0.4375, accuracy: 1e-9)
    }
}
