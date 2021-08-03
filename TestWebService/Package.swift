// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TestWebService",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(
            name: "TestWebService",
            targets: ["TestWebService"])
    ],
    dependencies: [
        .package(url: "https://github.com/Apodini/Apodini.git", .branch("develop"))
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "TestWebService",
            dependencies: [
            .product(name: "Apodini", package: "Apodini"),
            .product(name: "ApodiniREST", package: "Apodini"),
            .product(name: "ApodiniOpenAPI", package: "Apodini")
            ]),
        .testTarget(
            name: "TestWebServiceTests",
            dependencies: ["TestWebService"])
    ]
)
