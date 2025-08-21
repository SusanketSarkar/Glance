// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Glance",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Glance",
            targets: ["Glance"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Glance",
            dependencies: [],
            path: "src"
        )
    ]
) 