// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-device-discovery",
    platforms: [.macOS(.v10_15)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SwiftDeviceDiscovery",
            targets: ["DeviceDiscovery"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.4.0"),
        .package(url: "https://github.com/apple/swift-nio-ssh", from: "0.3.0"),
        .package(name: "swift-nio-lifx", url: "https://github.com/PSchmiedmayer/Swift-NIO-LIFX.git", .branch("develop")),
//        .package(name: "swift-nio-lifx", path: "/Users/felice/Documents/Swift-NIO-LIFX")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "DeviceDiscovery",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOSSH", package: "swift-nio-ssh"),
                .product(name: "NIOLIFX", package: "swift-nio-lifx")
            ]
        ),
        .testTarget(
            name: "DeviceDiscoveryTests",
            dependencies: ["DeviceDiscovery"]),
    ]
)
