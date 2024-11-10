// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Remark",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(
            name: "Remark",
            targets: ["Remark"]),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", branch: "master"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", branch: "main")
    ],
    targets: [
        .target(
            name: "Remark",
            dependencies: [
                "SwiftSoup"
            ]
        ),
        .executableTarget(
            name: "RemarkCLI",
            dependencies: [
                "Remark",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "RemarkTests",
            dependencies: ["Remark"]
        ),
    ]
)
