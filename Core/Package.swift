// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "agent-scrumban",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ScrumbanCore", targets: ["ScrumbanCore"]),
    ],
    targets: [
        .target(name: "ScrumbanCore"),
        .executableTarget(name: "scrumban", dependencies: ["ScrumbanCore"]),
        .testTarget(name: "ScrumbanCoreTests", dependencies: ["ScrumbanCore"]),
    ]
)
