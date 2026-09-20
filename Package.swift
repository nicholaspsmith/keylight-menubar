// swift-tools-version:5.9
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import PackageDescription

let package = Package(
    name: "KeyLight",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "KeyLight", targets: ["KeyLight"]),
        .library(name: "KeyLightCore", targets: ["KeyLightCore"]),
    ],
    dependencies: [
        .package(path: "../StatusItemKit"),
        .package(path: "../HotkeyKit"),
    ],
    targets: [
        .target(
            name: "KeyLightCore",
            dependencies: [.product(name: "HotkeyKit", package: "HotkeyKit")]
        ),
        .executableTarget(
            name: "KeyLight",
            dependencies: [
                "KeyLightCore",
                .product(name: "StatusItemKit", package: "StatusItemKit"),
                .product(name: "HotkeyKit", package: "HotkeyKit"),
            ]
        ),
        .testTarget(name: "KeyLightCoreTests", dependencies: ["KeyLightCore"]),
    ]
)
