import XCTest
@testable import KeyLightCore

final class IconStyleTests: XCTestCase {
    /// An isolated defaults domain, so the tests never touch the developer's
    /// real KeyLight preferences.
    private var defaults: UserDefaults!
    private let suiteName = "com.nicholaspsmith.KeyLight.IconStyleTests"

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

    func testLoadReturnsFallbackWhenUnset() {
        XCTAssertEqual(IconStyleStore.load(from: defaults), .fallback)
    }

    func testEveryStyleRoundTrips() {
        for style in IconStyle.allCases {
            IconStyleStore.save(style, to: defaults)
            XCTAssertEqual(IconStyleStore.load(from: defaults), style)
        }
    }

    func testUnknownRawValueLoadsAsFallback() {
        defaults.set("hexagon", forKey: IconStyleStore.defaultsKey)
        XCTAssertEqual(IconStyleStore.load(from: defaults), .fallback)
    }

    func testNonStringValueLoadsAsFallback() {
        defaults.set(42, forKey: IconStyleStore.defaultsKey)
        XCTAssertEqual(IconStyleStore.load(from: defaults), .fallback)
    }

    func testMenuOrderIsGaugeArcPieWedge() {
        XCTAssertEqual(IconStyle.allCases, [.gauge, .arc, .pie, .wedge])
    }

    func testEveryStyleHasANonEmptyLabel() {
        for style in IconStyle.allCases {
            XCTAssertFalse(style.label.isEmpty, "\(style) has no label")
        }
    }
}
