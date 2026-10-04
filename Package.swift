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
        )
    ],
    targets: [
        .executableTarget(
            name: "Testudo",
            path: "Sources/Testudo",
            exclude: ["Resources"]
        )
    ]
)
