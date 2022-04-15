// swift-tools-version:5.5

//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import PackageDescription

let package = Package(
    name: "SwiftDeviceDiscovery",
    platforms: [.macOS(.v11)],
    products: [
        .library(
            name: "SwiftDeviceDiscovery",
            targets: ["DeviceDiscovery"]
        ),
        .executable(name: "discovery-executable", targets: ["discovery-executable"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.4.0"),
        .package(url: "https://github.com/apple/swift-nio-ssh", from: "0.3.0"),
        .package(url: "https://github.com/Bouke/NetService.git", from: "0.8.1")
    ],
    targets: [
        .target(
            name: "DeviceDiscovery",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOSSH", package: "swift-nio-ssh"),
                .product(name: "NetService", package: "NetService")
            ]
        ),
        .executableTarget(
            name: "discovery-executable",
            dependencies: [
                .target(name: "DeviceDiscovery")
            ]
        ),
        .testTarget(
            name: "DeviceDiscoveryTests",
            dependencies: ["DeviceDiscovery"])
    ]
)
