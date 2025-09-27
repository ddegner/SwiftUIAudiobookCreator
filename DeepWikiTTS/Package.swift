// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeepWikiTTS",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "DeepWikiTTS", targets: ["DeepWikiTTS"]),
        .executable(name: "DeepWikiTTSApp", targets: ["DeepWikiTTSApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "DeepWikiTTS",
            dependencies: [
                .product(name: "SwiftSoup", package: "SwiftSoup"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "Sources/DeepWikiTTS"
        ),
        .executableTarget(
            name: "DeepWikiTTSApp",
            dependencies: ["DeepWikiTTS"],
            path: "Sources/DeepWikiTTSApp",
            resources: [ .process("Resources") ]
        ),
        .testTarget(
            name: "DeepWikiTTSTests",
            dependencies: ["DeepWikiTTS"],
            path: "Tests/DeepWikiTTSTests"
        )
    ]
)

