// swift-tools-version:5.9
import PackageDescription

var targets: [Target] = [
    // The rules of the board (3 Today / Missed / Next / Done, scheduling, days) and saving.
    // No UI, so the iPhone app can share it.
    .target(name: "ThreeThingsCore", path: "Sources/ThreeThingsCore"),
    .testTarget(name: "ThreeThingsCoreTests", dependencies: ["ThreeThingsCore"], path: "Tests/ThreeThingsCoreTests"),
]

#if os(macOS)
// The Mac app (SwiftUI). Left out elsewhere so the core and its tests also build on Linux.
targets.append(.executableTarget(name: "ThreeThings", dependencies: ["ThreeThingsCore"], path: "Sources/ThreeThings"))
#endif

let package = Package(
    name: "ThreeThings",
    platforms: [.macOS(.v13), .iOS(.v16)],
    targets: targets
)
