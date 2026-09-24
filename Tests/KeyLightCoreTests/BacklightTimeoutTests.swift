// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
@testable import KeyLightCore

final class BacklightTimeoutTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "com.nicholaspsmith.KeyLight.BacklightTimeoutTests"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testMenuOrderIsSecondsThenMinutesThenNever() {
        XCTAssertEqual(
            BacklightTimeout.allCases.map(\.seconds),
            [1, 2, 3, 4, 5, 60, 120, 300, 600, 0]
        )
    }

    func testNeverIsZeroSeconds() {
        XCTAssertEqual(BacklightTimeout.never.seconds, 0)
        XCTAssertEqual(BacklightTimeout(seconds: 0), .never)
    }

    func testLabels() {
        XCTAssertEqual(BacklightTimeout.seconds1.label, "1 second")
        XCTAssertEqual(BacklightTimeout.seconds2.label, "2 seconds")
        XCTAssertEqual(BacklightTimeout.minutes1.label, "1 minute")
        XCTAssertEqual(BacklightTimeout.minutes10.label, "10 minutes")
        XCTAssertEqual(BacklightTimeout.never.label, "Never")
    }

    func testSecondsRoundTripThroughInit() {
        for t in BacklightTimeout.allCases {
            XCTAssertEqual(BacklightTimeout(seconds: t.seconds), t)
        }
    }

    func testUnlistedSecondsMatchNothing() {
        // System Settings offers 10 s and 30 s; neither is in our menu, so no
        // row should claim it.
        XCTAssertNil(BacklightTimeout(seconds: 10))
        XCTAssertNil(BacklightTimeout(seconds: 30))
        XCTAssertNil(BacklightTimeout(seconds: 2.5))
    }

    func testLoadIsNilWhenNothingChosen() {
        XCTAssertNil(BacklightTimeoutStore.load(from: defaults))
    }

    func testEveryTimeoutRoundTrips() {
        for t in BacklightTimeout.allCases {
            BacklightTimeoutStore.save(t, to: defaults)
            XCTAssertEqual(BacklightTimeoutStore.load(from: defaults), t)
        }
    }

    func testUnknownStoredValueLoadsAsNil() {
        defaults.set(30.0, forKey: BacklightTimeoutStore.defaultsKey)
        XCTAssertNil(BacklightTimeoutStore.load(from: defaults))
        defaults.set("soon", forKey: BacklightTimeoutStore.defaultsKey)
        XCTAssertNil(BacklightTimeoutStore.load(from: defaults))
    }
}
