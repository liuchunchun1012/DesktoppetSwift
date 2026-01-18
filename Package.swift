// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Meowpal",
    platforms: [
        .macOS(.v12) // ScreenCaptureKit and other modern APIs require a recent macOS version.
    ],
    products: [
        .executable(name: "Meowpal", targets: ["Meowpal"])
    ],
    dependencies: [
        // No external dependencies for this phase.
    ],
    targets: [
        .executableTarget(
            name: "Meowpal",
            path: "Sources/Meowpal"
        )
    ]
)
