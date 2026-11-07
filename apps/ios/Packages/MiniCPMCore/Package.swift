// swift-tools-version: 6.3
import PackageDescription

// Rules, state and contracts for the MiniCPM client. No SwiftUI here, so rules stay separate from the views and test with `swift test`.
// The app target defaults to MainActor isolation. This library stays nonisolated: `AppModel` is marked `@MainActor`,
// and engines, stores and services are actors that must not run on the main thread.
let swiftSettings: [SwiftSetting] = [
    // The language features behind Xcode's "Approachable Concurrency" and "Member Import Visibility" settings.
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "MiniCPMCore",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [.library(name: "MiniCPMCore", targets: ["MiniCPMCore"])],
    targets: [
        .target(name: "MiniCPMCore", swiftSettings: swiftSettings),
        .testTarget(name: "MiniCPMCoreTests", dependencies: ["MiniCPMCore"], swiftSettings: swiftSettings),
    ]
)
