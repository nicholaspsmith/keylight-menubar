import XCTest
@testable import KeyLightCore

final class LevelMathTests: XCTestCase {
    private let step = 1.0 / 16.0

    func testUpAddsOneStep() {
        XCTAssertEqual(LevelMath.nextLevel(current: 0.5, step: step, direction: .up), 0.5625, accuracy: 1e-9)
    }

    func testDownSubtractsOneStep() {
        XCTAssertEqual(LevelMath.nextLevel(current: 0.5, step: step, direction: .down), 0.4375, accuracy: 1e-9)
    }

    func testUpClampsAtOne() {
        XCTAssertEqual(LevelMath.nextLevel(current: 0.97, step: step, direction: .up), 1.0, accuracy: 1e-9)
    }

    func testDownClampsAtZero() {
        XCTAssertEqual(LevelMath.nextLevel(current: 0.03, step: step, direction: .down), 0.0, accuracy: 1e-9)
    }

    func testUpFromMaxStaysMax() {
        XCTAssertEqual(LevelMath.nextLevel(current: 1.0, step: step, direction: .up), 1.0, accuracy: 1e-9)
    }

    func testDownFromZeroStaysZero() {
        XCTAssertEqual(LevelMath.nextLevel(current: 0.0, step: step, direction: .down), 0.0, accuracy: 1e-9)
    }
}
