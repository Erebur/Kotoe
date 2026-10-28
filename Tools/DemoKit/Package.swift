// swift-tools-version: 6.0
import PackageDescription

/// Development-only package for the headless demo renderer and its progress
/// HUD. The `KotoeDemo` target compiles the app's own sources through the
/// `Sources/KotoeDemo/Kotoe` symlink, so a demo always matches the working
/// tree.
let package = Package(
    name: "KotoeDemoKit",
    platforms: [.macOS("27.0")],
    dependencies: [
        .package(
            url: "https://github.com/mgriebling/SwiftMath.git",
            exact: "1.7.3"
        ),
        .package(
            url: "https://github.com/smittytone/HighlighterSwift.git",
            from: "3.1.0"
        ),
    ],
    targets: [
        .executableTarget(
            name: "KotoeDemo",
            dependencies: [
                .product(name: "SwiftMath", package: "SwiftMath"),
                .product(name: "Highlighter", package: "HighlighterSwift"),
            ],
            path: "Sources/KotoeDemo",
            exclude: [
                "Kotoe/FlashApp.swift",
                "Kotoe/Assets.xcassets",
                "Kotoe/Info.plist",
                "Kotoe/Kōtoe.entitlements",
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "KotoeDemoHUD",
            path: "Sources/KotoeDemoHUD",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
