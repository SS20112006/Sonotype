// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sonotype",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Sonotype",
            targets: ["Sonotype"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Sonotype",
            path: "Sources/Sonotype",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "SonotypeTests",
            dependencies: [
                "Sonotype"
            ],
            path: "Tests/SonotypeTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
