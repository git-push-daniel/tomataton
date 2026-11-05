// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TomatoKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "TomatoKit", targets: ["TomatoKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.12.0"),
    ],
    targets: [
        .target(
            name: "TomatoKit",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        .testTarget(
            name: "TomatoKitTests",
            dependencies: ["TomatoKit", .product(name: "GRDB", package: "GRDB.swift")]
        ),
    ]
)
