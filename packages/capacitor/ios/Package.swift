// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IOSPerformanceCapacitor",
    platforms: [.iOS(.v15)],
    products: [.library(name: "IOSPerformanceCapacitor", targets: ["IOSPerformanceCapacitor"])],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", "7.0.0"..<"10.0.0"),
        .package(path: "../../ios-core")
    ],
    targets: [
        .target(
            name: "IOSPerformanceCapacitor",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "IOSPerformanceCore", package: "ios-core")
            ],
            path: "Sources/IOSPerformance"
        )
    ]
)
