// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tweaky",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Tweaky", targets: ["Tweaky"])
    ],
    targets: [
        .executableTarget(name: "Tweaky"),
        .testTarget(name: "TweakyTests", dependencies: ["Tweaky"])
    ]
)
