// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
let uiTargets: [Target] = [
    .target(
        name: "RemarkUI",
        dependencies: ["RemarkKit"]
    )
]
let uiProducts: [Product] = [
    .library(
        name: "RemarkUI",
        targets: ["RemarkUI"]
    )
]
#else
let uiTargets: [Target] = []
let uiProducts: [Product] = []
#endif

let package = Package(
    name: "Remark",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(
            name: "RemarkKit",
            targets: ["RemarkKit"]),
        .executable(
            name: "remark",
            targets: ["RemarkCLI"]),
    ] + uiProducts,
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.11.3"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.0")
    ],
    targets: [
        .target(
            name: "RemarkKit",
            dependencies: [
                "SwiftSoup"
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
    ] + uiTargets
)
