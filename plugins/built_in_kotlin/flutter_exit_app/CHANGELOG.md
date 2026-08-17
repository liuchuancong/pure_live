# 2.1.2

* Fixed Swift Package Manager compatibility by migrating the iOS plugin implementation to 100% Swift (removing the mixed language Swift/Objective-C target structure which is not supported by SPM).

# 2.1.1

* Updated README version reference

# 2.1.0

**Swift Package Manager support and dependency upgrades**

## Breaking Changes
* **BREAKING**: Minimum iOS version increased from 12.0 to 13.0

## iOS Changes
* **SPM Support**: Added Swift Package Manager support while maintaining CocoaPods compatibility
* Restructured iOS sources to `ios/flutter_exit_app/Sources/flutter_exit_app/`
* Updated podspec to support dual CocoaPods and SPM integration

## Android Upgrades
* Updated Kotlin from 1.9.24 to 2.0.21
* Updated Android Gradle Plugin from 8.1.0 to 8.7.3
* Updated Gradle from 8.4 to 8.9
* Updated Java compatibility from 1.8 to 17
* Updated kotlin-stdlib-jdk8 to kotlin-stdlib

## Example App Updates
* Updated for new Flutter iOS architecture with `FlutterImplicitEngineDelegate`
* Added `UIApplicationSceneManifest` configuration for modern iOS scene management
* Updated minimum deployment target to iOS 13.0

## Notes
* Projects using CocoaPods will continue to work without changes
* New projects can opt to use Swift Package Manager

# 2.0.0

**Major modernization update with breaking changes**

## Breaking Changes
* **BREAKING**: Minimum Flutter version is now 3.10.0
* **BREAKING**: Minimum Dart version is now 3.0.0
* **BREAKING**: Minimum Android API level is now 21 (Android 5.0)
* **BREAKING**: Minimum iOS version is now 12.0
* **BREAKING**: Return type changed from `Future<bool?>` to `Future<bool>`

## Android Improvements
* **MIGRATION**: Migrated from Java to Kotlin for better performance and maintainability
* Updated Android Gradle Plugin to 8.1.0
* Updated Gradle to 8.4
* Updated compileSdk to 34
* Added namespace declaration for AGP 8.x compatibility
* Improved error handling with null-safety
* Better activity lifecycle management
* Cleaner, more idiomatic Kotlin code

## iOS Improvements
* Refactored iOS implementation to follow Apple best practices
* Added proper app lifecycle notification handling (`willResignActiveNotification`, `didEnterBackgroundNotification`)
* Improved graceful exit: app moves to background and suspends (iOS recommended behavior)
* Force-kill mode now includes 0.5s cleanup delay for proper state saving
* Better memory management with weak self references
* iOS 12+ compatibility with fallback for deprecated APIs
* Comprehensive documentation about App Store compliance

## Dart API Improvements
* Made constructor private to prevent unnecessary instantiation
* Added `@visibleForTesting` annotation for better testability
* Made MethodChannel `const` for performance
* Improved error handling with specific exception types
* Enhanced documentation with detailed examples and use cases
* Better null-safety handling

## Testing & Quality
* Replaced mockito with Flutter's built-in `TestDefaultBinaryMessengerBinding`
* No more code generation required for tests
* Added 6 comprehensive unit tests covering all scenarios
* Tests now verify both method calls and arguments
* All tests pass with zero warnings

## Documentation
* Completely rewrote README with clear examples and API reference
* Added migration guide from 1.x to 2.0
* Updated to use `flutter_lints` for better code quality
* Added platform support table
* Comprehensive inline code documentation
* Updated CLAUDE.md with modernization details

## Example App Updates
* Fixed AGP 8.x compatibility issues
* Updated Gradle wrapper to 8.4
* Added namespace declaration
* Added kotlinOptions configuration
* Example app now builds successfully on latest Flutter SDK

## Dependencies
* Updated to `flutter_lints: ^5.0.0` (replaced `lints`)
* Removed `mockito`, `build_runner`, and `test` dependencies
* Cleaner dependency tree

# 1.1.4

* Fix an issue [#2](https://github.com/xang555/flutter_exit_app/issues/2)

# 1.1.3

* Update version
* Add Test case
* Update example
* Update native code
* Fix an issue [#1](https://github.com/xang555/flutter_exit_app/issues/1)

# 1.1.2

* add `iosForceExit` parameter for `exitApp` method

# 1.1.1

* breaking: remove `exit(0)` for ios

# 1.1.0

* Fix kill ios process
* Add time wait for exit

# 1.0.5

* fix kill app in background when 1 sec

# 1.0.3

* fix docs
* android exit when 2000 msec

# 1.0.0

* Implement native android exit app
* Implement native ios exit app
* Add License