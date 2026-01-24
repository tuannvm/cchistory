// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CCHistory",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "CCHistory",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
            ],
            resources: [
                .process("Assets.xcassets"),
                .process("webui")
            ],
            linkerSettings: [
                .linkedFramework("Cocoa")
            ]
        ),
        .testTarget(
            name: "CCHistoryTests",
            dependencies: ["CCHistory"]
        )
    ]
)
