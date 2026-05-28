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
        .package(url: "https://github.com/krzysztofzablocki/Inject.git", branch: "main")
    ],
    targets: [
        .target(
            name: "VibeProxyCore",
            path: "Sources/VibeProxyCore"
        ),
        .executableTarget(
            name: "CLIProxyMenuBar",
            dependencies: ["Inject", "VibeProxyCore"],
            path: "Sources",
            exclude: ["VibeProxyCore"],
            resources: [
                .copy("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-enable-implicit-dynamic"], .when(configuration: .debug)),
                .unsafeFlags(["-suppress-warnings"], .when(configuration: .debug))
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-interposable"], .when(configuration: .debug))
            ]
        )
    ]
)
