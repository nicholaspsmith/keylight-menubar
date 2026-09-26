// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import XCTest
@testable import KeyLightCore

final class SubFloorStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    override func setUp() {
        defaults = UserDefaults(suiteName: "SubFloorStoreTests")!
        defaults.removePersistentDomain(forName: "SubFloorStoreTests")
    }

    func testParkedLevelRoundTrip() {
        XCTAssertNil(SubFloorStore.loadParkedLevel(from: defaults))
        SubFloorStore.saveParkedLevel(0.0001, to: defaults)
        XCTAssertEqual(SubFloorStore.loadParkedLevel(from: defaults), 0.0001)
        SubFloorStore.saveParkedLevel(nil, to: defaults)
        XCTAssertNil(SubFloorStore.loadParkedLevel(from: defaults))
    }

    func testNonSubFloorParkedLevelIsIgnored() {
        defaults.set(0.5, forKey: SubFloorStore.parkedLevelKey)
        XCTAssertNil(SubFloorStore.loadParkedLevel(from: defaults))
    }

    func testPendingRestoreRoundTrip() {
        XCTAssertNil(SubFloorStore.loadPendingRestore(from: defaults))
        SubFloorStore.savePendingRestore(autoBrightness: true, to: defaults)
        XCTAssertEqual(SubFloorStore.loadPendingRestore(from: defaults), true)
        SubFloorStore.savePendingRestore(autoBrightness: false, to: defaults)
        XCTAssertEqual(SubFloorStore.loadPendingRestore(from: defaults), false)
        SubFloorStore.savePendingRestore(autoBrightness: nil, to: defaults)
        XCTAssertNil(SubFloorStore.loadPendingRestore(from: defaults))
    }
}
