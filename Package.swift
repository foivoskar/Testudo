// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Testudo",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(
            name: "Testudo",
            targets: ["Testudo"]
        ),
        .library(
            name: "TestudoCore",
            targets: ["TestudoCore"]
        )
    ],
    targets: [
        .target(
            name: "TestudoCore",
            path: "Sources/TestudoCore"
        ),
        .executableTarget(
            name: "Testudo",
            dependencies: ["TestudoCore"],
            path: "Sources/Testudo",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "TestudoCoreTests",
            dependencies: ["TestudoCore"],
            path: "Tests/TestudoCoreTests"
        ),
        .testTarget(
            name: "TestudoIntegrationTests",
            dependencies: ["Testudo"],
            path: "Tests/TestudoIntegrationTests"
        )
    ]
)
