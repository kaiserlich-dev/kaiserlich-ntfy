// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NtfyBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NtfyBar", targets: ["NtfyBar"]),
    ],
    targets: [
        .executableTarget(
            name: "NtfyBar",
            path: "Sources"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
