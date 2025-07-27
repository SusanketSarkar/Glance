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
            path: ".",
            exclude: [
                "docs",
                "build.sh",
                "Glance.entitlements",
                "Info.plist",
                "README.md"
            ],
            sources: [
                "GlanceApp.swift",
                "ContentView.swift",
                "PDFViewWrapper.swift"
            ]
        )
    ]
) 