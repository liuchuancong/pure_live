// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

/// Checks whether a sibling SPM package exists at the given relative path.
///
/// Used to determine whether the native media libs package (e.g. `media_kit_libs_macos_video`)
/// has been included by the developer in their `pubspec.yaml`. When found, `media_kit_video` is
/// linked against it; otherwise it falls back to a stub implementation.
///
/// NOTE: This function is duplicated across iOS and macOS `Package.swift` manifests.
///
/// WARNING: After adding or removing the libs package from `pubspec.yaml`, the Swift Package
/// Manager cache must be cleared manually for the change to take effect:
///
///     rm -rf ~/Library/Caches/org.swift.swiftpm/
func packageExists(at relativePath: String) -> Bool {
    let base = URL(fileURLWithPath: #file).deletingLastPathComponent()
    let path = base.appendingPathComponent(relativePath).standardized.path
    return FileManager.default.fileExists(atPath: path)
}

let libsPath = "../media_kit_libs_macos_video"
let hasLibs = packageExists(at: libsPath)

let package = Package(
    name: "media_kit_video",
    platforms: [
        .macOS("10.9")
    ],
    products: [
        .library(name: "media-kit-video", targets: ["media_kit_video"])
    ],
    dependencies: hasLibs
        ? [.package(name: "media_kit_libs_macos_video", path: libsPath)]
        : [],
    targets: [
        .target(
            name: "media_kit_video",
            dependencies: hasLibs
                ? [.product(name: "Mpv", package: "media_kit_libs_macos_video")]
                : [],
            sources: hasLibs
                ? ["plugin"]
                : ["stub"],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
