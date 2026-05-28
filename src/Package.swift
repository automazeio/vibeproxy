// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CLIProxyMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CLIProxyMenuBar",
            targets: ["CLIProxyMenuBar"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.1.3")
    ],
    targets: [
        .executableTarget(
            name: "CLIProxyMenuBar",
            dependencies: ["Sparkle", "Yams"],
            path: "Sources",
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "CLIProxyMenuBarTests",
            dependencies: ["CLIProxyMenuBar"],
            path: "Tests"
        )
    ]
)
