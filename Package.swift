// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Remark",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(
            name: "RemarkKit",
            targets: ["RemarkKit"]),
        .library(
            name: "RemarkUI",
            targets: ["RemarkUI"]),
        .executable(
            name: "remark",
            targets: ["RemarkCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", branch: "master"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", branch: "main")
    ],
    targets: [
        .target(
            name: "RemarkKit",
            dependencies: [
                "SwiftSoup"
            ]
        ),
        .target(
            name: "RemarkUI",
            dependencies: [
                "RemarkKit"
            ]
        ),
        .executableTarget(
            name: "RemarkCLI",
            dependencies: [
                "RemarkKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "RemarkTests",
            dependencies: ["RemarkKit"]
        ),
    ]
)
