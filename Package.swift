// swift-tools-version:5.9
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
