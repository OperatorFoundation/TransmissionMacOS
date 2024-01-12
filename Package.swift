// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if (os(macOS) || os(iOS) || os(watchOS) || os(tvOS))
let package = Package(
    name: "TransmissionMacOS",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "TransmissionMacOS",
            targets: ["TransmissionMacOS"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/OperatorFoundation/Chord", branch: "release"),
        .package(url: "https://github.com/OperatorFoundation/Datable", from: "4.0.0"),
        .package(url: "https://github.com/OperatorFoundation/SwiftHexTools", from: "1.2.6"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.3"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionBase", branch: "release"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionTypes", branch: "release"),
        .package(url: "https://github.com/OperatorFoundation/Transport", branch: "release"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "TransmissionMacOS",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),

                "Chord",
                "Datable",
                "SwiftHexTools",
                "Transport",
                "TransmissionBase",
                "TransmissionTypes",
            ]
        ),
        .testTarget(
            name: "TransmissionMacOSTests",
            dependencies: ["TransmissionMacOS", "Datable"]),
    ],
    swiftLanguageVersions: [.v5]
)
#endif
