// swift-tools-version: 6.3
import PackageDescription

// Rules, state and contracts for the MiniCPM client. No SwiftUI here, so it builds and tests on Linux too.
let package = Package(
    name: "MiniCPMCore",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [.library(name: "MiniCPMCore", targets: ["MiniCPMCore"])],
    targets: [
        .target(name: "MiniCPMCore"),
        .testTarget(name: "MiniCPMCoreTests", dependencies: ["MiniCPMCore"]),
    ]
)
