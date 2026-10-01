// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DReport",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "DReport",
            targets: ["DReport"]
        )
    ],
    targets: [
        .executableTarget(
            name: "DReport",
            path: "Sources/DReport"
        )
    ]
)
