// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IOSPerformanceCore",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [.library(name: "IOSPerformanceCore", targets: ["IOSPerformanceCore"])],
    targets: [
        .target(name: "IOSPerformanceCore"),
        .testTarget(name: "IOSPerformanceCoreTests", dependencies: ["IOSPerformanceCore"])
    ]
)
