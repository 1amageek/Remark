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
        .package(url: "https://github.com/scinfu/SwiftSoup.git", branch: "master")
    ],
    targets: [
        .target(
            name: "Remark",
            dependencies: [
                "SwiftSoup"
            ]
        ),
        .testTarget(
            name: "RemarkTests",
            dependencies: ["Remark"]
        ),
    ]
)
