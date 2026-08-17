// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "better_player_plus",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "better-player-plus", targets: ["better_player_plus"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // Pinned to 6.x to match the CocoaPods dependency (Cache 7.x is not
        // published on CocoaPods) and the Storage initializer without fileManager.
        .package(url: "https://github.com/hyperoslo/Cache.git", "6.0.0"..<"7.0.0"),
    ],
    targets: [
        .target(
            name: "GCDWebServer"
        ),
        .target(
            name: "PINCache"
        ),
        .target(
            name: "HLSCachingReverseProxyServer",
            dependencies: [
                .target(name: "GCDWebServer"),
                .target(name: "PINCache"),
            ]
        ),
        .target(
            name: "better_player_plus",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "Cache", package: "Cache"),
                .target(name: "GCDWebServer"),
                .target(name: "PINCache"),
                .target(name: "HLSCachingReverseProxyServer"),
            ],
            exclude: [
                "BetterPlayerPlugin.h",
                "BetterPlayerPlugin.m",
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)
