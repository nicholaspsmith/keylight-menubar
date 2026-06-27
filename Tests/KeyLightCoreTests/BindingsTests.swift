import XCTest
import HotkeyKit
@testable import KeyLightCore

final class BindingsTests: XCTestCase {
    func testDefaultsAreCtrlBrightnessKeys() {
        let defaults = BindingStore.defaults
        XCTAssertEqual(defaults.count, 2)
        XCTAssertEqual(defaults[0].trigger, .mediaKey(2, .control))   // Up
        XCTAssertEqual(defaults[1].trigger, .mediaKey(3, .control))   // Down
    }

    func testResolveWithNoOverridesReturnsDefaults() {
        XCTAssertEqual(BindingStore.resolve(overrides: [:]), BindingStore.defaults)
    }

    func testResolveAppliesOverrideForKnownToken() {
        let newTrigger = Trigger.key(8, [.control, .option, .command])  // Ctrl+Opt+Cmd+C
        let resolved = BindingStore.resolve(overrides: ["backlight.up": newTrigger])

        let up = resolved.first { $0.token == "backlight.up" }
        let down = resolved.first { $0.token == "backlight.down" }
        XCTAssertEqual(up?.trigger, newTrigger)
        XCTAssertEqual(down?.trigger, .mediaKey(3, .control))   // untouched
    }

    func testResolveIgnoresUnknownToken() {
        let resolved = BindingStore.resolve(overrides: ["bogus.token": .key(0, [])])
        XCTAssertEqual(resolved, BindingStore.defaults)
    }

    func testResolvePreservesOrder() {
        let resolved = BindingStore.resolve(overrides: ["backlight.down": .key(9, .shift)])
        XCTAssertEqual(resolved.map(\.token), ["backlight.up", "backlight.down"])
    }

    func testOverridesJSONRoundTrip() throws {
        // Persistence relies on Trigger Codable through JSON.
        let overrides: [String: Trigger] = [
            "backlight.up": .key(8, [.control, .option, .command]),
            "backlight.down": .mediaKey(3, .control),
        ]
        let data = try JSONEncoder().encode(overrides)
        let decoded = try JSONDecoder().decode([String: Trigger].self, from: data)
        XCTAssertEqual(decoded, overrides)
        XCTAssertEqual(BindingStore.resolve(overrides: decoded),
                       BindingStore.resolve(overrides: overrides))
    }
}
