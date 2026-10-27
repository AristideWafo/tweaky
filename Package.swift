// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickText",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "QuickText", targets: ["QuickText"])
    ],
    targets: [
        .executableTarget(name: "QuickText"),
        .testTarget(name: "QuickTextTests", dependencies: ["QuickText"])
    ]
)
