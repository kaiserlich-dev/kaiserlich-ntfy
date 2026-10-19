// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NtfyBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NtfyBar", targets: ["NtfyBar"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.6.4"),
    ],
    targets: [
        .executableTarget(
            name: "NtfyBar",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources",
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
