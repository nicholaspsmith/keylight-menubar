// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
@testable import KeyLightCore

final class PWMCalibrationTests: XCTestCase {
    /// First bytes of this M5 Pro's `nits-to-pwm-percentage-part2`: 5.6% in 16.16.
    private let m5Table = Data([0x99, 0x99, 0x05, 0x00, 0xeb, 0x11, 0x06, 0x00])

    func testReadsFloorFromTable() {
        XCTAssertEqual(PWMCalibration.floorTicks(percentTable: m5Table, period: 960), 54)
    }
    func testScalesWithPeriod() {
        XCTAssertEqual(PWMCalibration.floorTicks(percentTable: m5Table, period: 1920), 108)
    }
    func testMissingTableFallsBack() {
        XCTAssertEqual(PWMCalibration.floorTicks(percentTable: nil, period: 960), 54)
    }
    func testMissingPeriodUsesDefault() {
        XCTAssertEqual(PWMCalibration.floorTicks(percentTable: m5Table, period: nil), 54)
    }
    func testShortTableFallsBack() {
        XCTAssertEqual(PWMCalibration.floorTicks(percentTable: Data([0x99, 0x99]), period: 960), 54)
    }
    func testImplausibleValueFallsBack() {
        XCTAssertEqual(PWMCalibration.floorTicks(percentTable: Data([0, 0, 0, 0]), period: 960), 54)
        XCTAssertEqual(PWMCalibration.floorTicks(percentTable: Data([0, 0, 0x50, 0]), period: 960), 54, "80% is not a floor")
    }
}
