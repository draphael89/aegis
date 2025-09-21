// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MetaKit",
    products: [
        .library(
            name: "MetaKit",
            targets: ["MetaKit"]
        ),
    ],
    dependencies: [
        .package(name: "CoreEngine", path: "../CoreEngine")
    ],
    targets: [
        .target(
            name: "MetaKit",
            dependencies: [
                .product(name: "CoreEngine", package: "CoreEngine")
            ]
        ),
        .testTarget(
            name: "MetaKitTests",
            dependencies: ["MetaKit"]
        ),
    ]
)
