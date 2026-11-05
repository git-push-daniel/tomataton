// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TomatoKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "TomatoKit", targets: ["TomatoKit"]),
    ],
    targets: [
        .target(name: "TomatoKit"),
        .testTarget(name: "TomatoKitTests", dependencies: ["TomatoKit"]),
    ]
)
