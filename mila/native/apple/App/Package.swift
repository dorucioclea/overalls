// swift-tools-version: 6.1

import PackageDescription

// The process entry point for the Mila iOS and macOS app. Behaviour lives in
// MilaNativeUI; build.sh turns this executable into a signed app bundle.
let package = Package(
    name: "MilaApp",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    dependencies: [
        .package(name: "MilaNativeUI", path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "Mila",
            dependencies: [.product(name: "MilaNativeUI", package: "MilaNativeUI")],
            path: "Sources/Mila"
        ),
    ]
)
