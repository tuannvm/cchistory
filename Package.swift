// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CCHistory",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "CCHistory",
            resources: [.process("Assets.xcassets")],
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("UserNotifications")
            ]
        ),
        .testTarget(
            name: "CCHistoryTests",
            dependencies: ["CCHistory"]
        )
    ]
)
