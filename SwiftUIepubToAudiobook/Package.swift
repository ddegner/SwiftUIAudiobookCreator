// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftUIepubToAudiobook",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .executable(name: "SwiftUIepubToAudiobook", targets: ["SwiftUIepubToAudiobook"])
    ],
    dependencies: [
        .package(url: "https://github.com/witekbobrowski/EPUBKit.git", from: "0.4.0"),
        .package(url: "https://github.com/mlalma/kokoro-ios.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-numerics.git", from: "1.0.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.25.0")
    ],
    targets: [
        .executableTarget(
            name: "SwiftUIepubToAudiobook",
            dependencies: [
                .product(name: "EPUBKit", package: "EPUBKit"),
                .product(name: "KokoroSwift", package: "kokoro-ios"),
                .product(name: "Numerics", package: "swift-numerics"),
                .product(name: "RealModule", package: "swift-numerics"),
                .product(name: "ComplexModule", package: "swift-numerics"),
                .product(name: "MLX", package: "mlx-swift")
            ],
            swiftSettings: [
                // Enable aggressive optimizations for release builds
                .unsafeFlags(["-O", "-whole-module-optimization"], .when(configuration: .release)),
                // Enable additional optimizations
                .unsafeFlags(["-Xfrontend", "-enable-actor-data-race-checks"], .when(configuration: .debug)),
                // Optimize for size in release
                .unsafeFlags(["-Osize"], .when(configuration: .release))
            ]
        )
    ]
)
