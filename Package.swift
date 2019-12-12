// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "APIClient",
    platforms: [
        .macOS(.v10_13), .iOS(.v10), .watchOS(.v3), .tvOS(.v10),
    ],
    products: [
        .library(
            name: "APIClient",
            targets: ["APIClient"]),
    ],
    targets: [
        .target(
            name: "APIClient",
            dependencies: []),
    ]
)
