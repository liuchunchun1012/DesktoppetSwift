// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "DesktoppetSwift",
    platforms: [
        .macOS(.v12) // ScreenCaptureKit and other modern APIs require a recent macOS version.
    ],
    products: [
        .executable(name: "DesktoppetSwift", targets: ["DesktoppetSwift"])
    ],
    dependencies: [
        // No external dependencies for this phase.
    ],
    targets: [
        .executableTarget(
            name: "DesktoppetSwift",
            path: "Sources/DesktoppetSwift"
        )
    ]
)
