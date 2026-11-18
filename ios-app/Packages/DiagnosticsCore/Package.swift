// swift-tools-version:5.9
// DiagnosticsCore: everything that is not presentation.
// iOS 14 is the minimum. Xcode 16 and newer cannot build below
// iOS 15 and quietly raise this; the iOS 14 build comes from Xcode 15 on the legacy Mac.
// The macOS platform exists only so the pure-logic unit tests can run with `swift test`
// on a Mac. Hardware code is wrapped in `#if os(iOS)`.

import PackageDescription

let package = Package(
    name: "DiagnosticsCore",
    platforms: [
        .iOS(.v14),
        .macOS(.v12),
    ],
    products: [
        .library(name: "DiagnosticsCore", targets: ["DiagnosticsCore"]),
    ],
    targets: [
        .target(name: "DiagnosticsCore"),
        .testTarget(name: "DiagnosticsCoreTests", dependencies: ["DiagnosticsCore"]),
    ]
)
