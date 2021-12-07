// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if (os(macOS) || os(iOS) || os(watchOS) || os(tvOS))
let package = Package(
    name: "TransmissionMacOS",
    platforms: [.macOS(.v10_15)],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "TransmissionMacOS",
            targets: ["TransmissionMacOS"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionTypes.git", from: "0.0.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/OperatorFoundation/Chord", from: "0.0.15"),
        .package(url: "https://github.com/OperatorFoundation/Datable", from: "3.1.4"),
        .package(url: "https://github.com/OperatorFoundation/Transport", from: "2.3.11"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "TransmissionMacOS",
            dependencies: ["TransmissionTypes", "Chord", "Datable", "Transport", .product(name: "Logging", package: "swift-log")]
        ),
        .testTarget(
            name: "TransmissionMacOSTests",
            dependencies: ["TransmissionMacOS", "Datable"]),
    ],
    swiftLanguageVersions: [.v5]
)
#endif
