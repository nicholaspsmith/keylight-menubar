// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
@testable import KeyLightCore

final class AdjustWakeTests: XCTestCase {
    func testAdjustingSuspendsIdleDimmingOnce() {
        var w = AdjustWake()
        XCTAssertTrue(w.userAdjusted(lidClosed: false))
        XCTAssertTrue(w.isHolding)
        // Already suspended: a second drag needs nothing new.
        XCTAssertFalse(w.userAdjusted(lidClosed: false))
    }

    func testLidClosedNeverSuspends() {
        var w = AdjustWake()
        XCTAssertFalse(w.userAdjusted(lidClosed: true))
        XCTAssertFalse(w.isHolding)
    }

    func testStaysSuspendedWhileInputIsRecent() {
        var w = AdjustWake()
        w.userAdjusted(lidClosed: false)
        XCTAssertFalse(w.tick(idleSeconds: 3.9, timeout: 4, lidClosed: false))
        XCTAssertTrue(w.isHolding)
    }

    func testResumesOnceIdleReachesTheTimeout() {
        var w = AdjustWake()
        w.userAdjusted(lidClosed: false)
        XCTAssertTrue(w.tick(idleSeconds: 4, timeout: 4, lidClosed: false))
        XCTAssertFalse(w.isHolding)
        XCTAssertFalse(w.tick(idleSeconds: 9, timeout: 4, lidClosed: false))
    }

    func testResumesWhenTheLidCloses() {
        var w = AdjustWake()
        w.userAdjusted(lidClosed: false)
        XCTAssertTrue(w.tick(idleSeconds: 0, timeout: 4, lidClosed: true))
        XCTAssertFalse(w.isHolding)
    }

    func testNeverTimeoutResumesImmediately() {
        // Timeout 0 = the backlight never dims, so there is nothing to hold off.
        var w = AdjustWake()
        w.userAdjusted(lidClosed: false)
        XCTAssertTrue(w.tick(idleSeconds: 0, timeout: 0, lidClosed: false))
    }

    func testCancelDropsTheHoldWithoutResuming() {
        // The sub-floor driver takes over idle dimming itself.
        var w = AdjustWake()
        w.userAdjusted(lidClosed: false)
        w.cancel()
        XCTAssertFalse(w.isHolding)
        XCTAssertFalse(w.tick(idleSeconds: 9, timeout: 4, lidClosed: false))
    }
}
