// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "McWhisper",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.12.0"),
    ],
    targets: [
        .executableTarget(
            name: "McWhisper",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "Sources/McWhisper"
        ),
        .testTarget(
            name: "McWhisperTests",
            dependencies: ["McWhisper"],
            path: "Tests/McWhisperTests"
        ),
    ]
)
