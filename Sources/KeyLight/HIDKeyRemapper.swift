// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import Foundation
import HotkeyKit
import IOKit.hidsystem
import KeyLightCore

/// Puts `HIDKeyRemap` on every keyboard that isn't Apple's, the way
/// `hidutil property --set UserKeyMapping` does. Needs no permission. The
/// mapping lives on the HID service and dies with it, so a keyboard that
/// reconnects comes back plain; `sync` runs on every poll tick to catch it.
final class HIDKeyRemapper {
    private let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
    private let mappingKey = kIOHIDUserKeyUsageMapKey as CFString

    /// Add the remap to (or take it off) every third-party keyboard; touches
    /// only keyboards whose mapping would change.
    func sync(enabled: Bool) {
        guard let services = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient] else { return }
        for service in services where isThirdPartyKeyboard(service) {
            let current = mapping(of: service)
            let wanted = HIDKeyRemap.merged(existing: current, enabled: enabled)
            guard wanted != current else { continue }
            let plist = wanted.map { [HIDKeyRemap.srcKey: $0.src, HIDKeyRemap.dstKey: $0.dst] } as CFArray
            let ok = IOHIDServiceClientSetProperty(service, mappingKey, plist)
            let name = IOHIDServiceClientCopyProperty(service, kIOHIDProductKey as CFString) as? String ?? "?"
            log.info("\(enabled ? "remap" : "unmap", privacy: .public) \(name, privacy: .public): \(ok ? "ok" : "failed", privacy: .public)")
        }
    }

    private func isThirdPartyKeyboard(_ service: IOHIDServiceClient) -> Bool {
        guard IOHIDServiceClientConformsTo(service, UInt32(kHIDPage_GenericDesktop), UInt32(kHIDUsage_GD_Keyboard)) != 0 else {
            return false
        }
        let vendor = IOHIDServiceClientCopyProperty(service, kIOHIDVendorIDKey as CFString) as? Int
        let builtIn = IOHIDServiceClientCopyProperty(service, kIOHIDBuiltInKey as CFString) as? Bool ?? false
        return !KeyboardIdentity.isApple(vendorID: vendor, builtIn: builtIn)
    }

    private func mapping(of service: IOHIDServiceClient) -> [HIDKeyRemap.Entry] {
        let raw = IOHIDServiceClientCopyProperty(service, mappingKey) as? [[String: Any]] ?? []
        return raw.compactMap { entry in
            guard let src = (entry[HIDKeyRemap.srcKey] as? NSNumber)?.int64Value,
                  let dst = (entry[HIDKeyRemap.dstKey] as? NSNumber)?.int64Value else { return nil }
            return HIDKeyRemap.Entry(src: src, dst: dst)
        }
    }
}
