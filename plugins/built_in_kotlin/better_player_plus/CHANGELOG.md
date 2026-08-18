## 1.3.5

* Fixed Android hardware decoder failure by adding software decoder fallback (thanks @ZhaosongRen)
* Fixed Android play/pause notification state not syncing from native player changes (thanks @mmeshrif)
* Fixed `NullPointerException` in `_BetterPlayerVideoFitWidgetState.dispose` and unassigned ClearKey `DrmSessionManager` on Android (thanks @vivek995378)
* Fixed Simplified Chinese translations (thanks @zs)

## 1.3.4

* Fixed iOS build error: duplicate `BetterPlayerPlugin` interface definition caused by CocoaPods exposing ObjC header alongside Swift-generated header; excluded `BetterPlayerPlugin.h/m` from podspec source files
* Fixed iOS Profile build configuration missing `Profile.xcconfig`, causing CocoaPods base config conflict
* Fixed Android example `build.gradle.kts` missing `org.jetbrains.kotlin.android` plugin, causing unresolved `kotlin { compilerOptions }` block

## 1.3.3

* Fixed iOS podspec version mismatch (was stuck at `1.3.0`), now synced with `pubspec.yaml`
* Fixed initial track setup not awaiting `setTrack`, which could race with data source setup

## 1.3.2

* Fixed iOS HLS playback with `useCache: true` for modern fMP4/CMAF streams (`#EXT-X-MAP`, `.m4s`, external audio renditions) by playing HLS directly through `AVURLAsset` instead of the localhost reverse proxy
* Fixed iOS Swift compile errors: aligned `Cache` dependency to 6.x for both CocoaPods and SPM (Cache 7.x is not published on CocoaPods) and restored the `AVURLAssetHTTPHeaderFieldsKey` string literal
* Fixed player layout not refreshing after manual HLS/DASH quality track switch: `setTrack` now updates the reported video size and emits a `changedTrack` controller event
* Fixed duplicate `@interface BetterPlayerPlugin` definition in the iOS plugin header
* Hardened iOS HLS header conversion with typed `String`/`NSNumber` handling
* Removed unused `HLSCachingReverseProxyServer`, `GCDWebServer` and `PINCache` dependencies from the iOS podspec
* Optimized iOS BoxFit handling with scheduled application
* `CacheManager.setup()` is now a deprecated no-op on iOS (no HLS proxy setup needed)

## 1.3.1

* Updated iOS dependencies and cleaned up stale SPM `Package.resolved` pins
* Minor cleanup in `better_player_with_controls.dart`

## 1.3.0

* Added iOS Swift Package Manager (SPM) support
* Added `Package.swift` to support native SPM integration
* Migrated iOS plugin source files from `Classes/` to `better_player_plus/Sources/better_player_plus/` for SPM compatibility
* Cleaned up legacy CocoaPods integration from the iOS example project for smoother SPM-based builds

## 1.2.1

* Fixed MissingPluginException for `setAspectRatio` on Android by guarding the call with `Platform.isIOS`

## 1.2.0

* Dart SDK updated → 3.11.0, Flutter SDK updated → 3.41.0
* Android Media3 updated → 1.10.0
* Fixed controlsVisibilityStream feedback loop by guarding against duplicate state updates
* Fixed controlsVisibilityStream not emitting when UI auto-hides
* Fixed aspect ratio issues for iOS AVPlayer
* Fixed audio track override not being cleared before applying a new one
* Preserved iOS playback speed across player actions (seek, pause, resume)
* Fixed HLS parsing for default audio source selection in HLS streams
* Added iOS wakelock (disable auto-sleep) support during playback
* Resolved all dart analyze warnings and errors (zero issues)

## 1.1.5

* Fixed error in WebVTT file parser for subtitle handling
* Fixed issue where 'hideFullscreen' event was not fired when exiting fullscreen mode
* Improved subtitle parsing reliability and error handling

## 1.1.4

* Added custom controls configuration feature for enhanced player customization
* Fixed Android Kotlin build errors and compatibility issues
* Fixed player reference usage when accessing DRM, timeline, and video format
* Improved DrmSessionManagerProvider initialization with safe let expressions
* Enhanced video format access with proper null safety guards
* Minor code improvements and optimizations

## 1.1.3

* Documentation improvements with enhanced README formatting and structure
* Added LinkedIn contact information for Flutter-related inquiries
* Code cleanup: Removed unnecessary TODO comments
* Improved text readability and formatting throughout documentation
* Minor version bump with maintenance updates

## 1.1.2

* Fixed missing type annotation in method_channel_video_player.dart
* Updated iOS podspec metadata with proper project information
* Fixed example app dependency version constraints
* Improved code quality and static analysis compliance
* Enhanced project documentation and version consistency

## 1.1.1

* iOS implementation migrated from Objective-C to Swift
* Fixed Swift compiler errors and deprecated API usage
* Removed deprecated GLKit dependency
* Updated UIApplication.keyWindow usage for iOS 13+ compatibility
* Improved plugin registration with proper Objective-C bridging
* Enhanced code maintainability and modern iOS development practices
* Special thanks to Cursor AI for assistance with the migration

## 1.1.0

* Flutter SDK updated → 3.35.0
* Dart SDK updated → 3.9.0
* Gradle updated → 8.13.0
* Kotlin Gradle Plugin updated → 2.2.20
* Android Media3 Player updated → 1.8.0
* Minimum iOS version raised to → 13
* Package updates and compatibility improvements

## 1.0.8

* package update

## 1.0.7

* package update

## 1.0.6

* package update.
* Kotlin version update to 1.9.22
* Media3 version update to 1.3.1
* gradle version update to 8.1.4
* targetSdkVersion update to 34

## 1.0.5

* package update

## 1.0.4

* ios player bug fix

## 1.0.3

* ExoPlayer migration Media3

## 1.0.2

* bug fix

## 1.0.1

* bug fix

## 1.0.0

* Initial release.
