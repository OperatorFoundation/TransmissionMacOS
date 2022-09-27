// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if (os(macOS) || os(iOS) || os(watchOS) || os(tvOS))
let package = Package(
    name: "TransmissionMacOS",
    platforms: [.macOS(.v12),
                       .iOS(.v15)
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
        .package(url: "https://github.com/OperatorFoundation/Chord", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Datable", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/SwiftHexTools", branch: "main"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.2"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionTypes.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Transport", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "TransmissionMacOS",
            dependencies: [
                "Chord",
                "Datable",
                .product(name: "Logging", package: "swift-log"),
                "SwiftHexTools",
                "Transport",
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
