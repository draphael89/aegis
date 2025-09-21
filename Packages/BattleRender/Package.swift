// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BattleRender",
    products: [
        .library(
            name: "BattleRender",
            targets: ["BattleRender"]
        ),
    ],
    dependencies: [
        .package(name: "CoreEngine", path: "../CoreEngine"),
        .package(name: "MetaKit", path: "../MetaKit")
    ],
    targets: [
        .target(
            name: "BattleRender",
            dependencies: [
                .product(name: "CoreEngine", package: "CoreEngine"),
                .product(name: "MetaKit", package: "MetaKit")
            ]
        ),
        .testTarget(
            name: "BattleRenderTests",
            dependencies: ["BattleRender", .product(name: "MetaKit", package: "MetaKit")]
        ),
    ]
)
