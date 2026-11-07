// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Linefeed",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Linefeed", targets: ["Linefeed"]),
        .library(name: "LinefeedCore", targets: ["LinefeedCore"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            revision: "6428e29186573c6d33c598e25d460e6690bc0ee1"
        )
    ],
    targets: [
        .target(name: "LinefeedCore"),
        .executableTarget(
            name: "Linefeed",
            dependencies: [
                "LinefeedCore",
                .product(name: "FluidAudio", package: "FluidAudio")
            ]
        ),
        .testTarget(name: "LinefeedCoreTests", dependencies: ["LinefeedCore"]),
        .testTarget(name: "LinefeedAppTests", dependencies: ["Linefeed"])
    ]
)
