// swift-tools-version: 6.2
import PackageDescription

/// Shared Core layer for Vittora app + future Widget / Watch / App Intents targets.
/// Migration: move `Vittora/Core/{Domain,Data,Security,Sync}` into `Sources/VittoraCore`
/// and link this package from the app target (J2).
let package = Package(
    name: "VittoraCore",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "VittoraCore",
            targets: ["VittoraCore"]
        ),
    ],
    targets: [
        .target(
            name: "VittoraCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
