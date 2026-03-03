// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "aim-clicker",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "aim-clicker", targets: ["aim-clicker"]),
    ],
    targets: [
        .target(
            name: "AimClickerCore",
            path: "Sources/AimClickerCore"
        ),
        .executableTarget(
            name: "aim-clicker",
            dependencies: ["AimClickerCore"],
            path: "Sources/aim-clicker"
        ),
        .testTarget(
            name: "AimClickerCoreTests",
            dependencies: ["AimClickerCore"],
            path: "Tests/AimClickerCoreTests"
        ),
    ]
)
