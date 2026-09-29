// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "fvp",
    platforms: [
        .iOS("12.0"),
        .macOS("10.13"),
    ],
    products: [
        .library(name: "fvp", type: .dynamic, targets: ["fvp"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "fvp",
            dependencies: [
                .target(name: "mdk"),
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: ".",
            sources: [
                "Sources/fvp/FvpPlugin.mm",
                "Sources/fvp/callbacks.cpp",
            ],
            resources: [
                .process("Resources/PrivacyInfo.xcprivacy"),
            ],
            publicHeadersPath: "Sources/fvp",
            cSettings: [
                .headerSearchPath("Sources/fvp"),
            ],
            cxxSettings: [
                .unsafeFlags(["-Wno-documentation"]),
            ],
            linkerSettings: [
                .linkedFramework("Flutter", .when(platforms: [.iOS])),
                .linkedFramework("FlutterMacOS", .when(platforms: [.macOS])),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Metal"),
            ]
        ),
        .binaryTarget(
            name: "mdk",
            url: "https://github.com/wang-bin/mdk-sdk/releases/download/v0.38.0/mdk-sdk-apple.zip",
            checksum: "dfae61b90ae1cc543d173b3b4cf2411856c98d61a3a56d7b032573080b8d18a5"
        ),
    ],
    cxxLanguageStandard: .cxx20
)
