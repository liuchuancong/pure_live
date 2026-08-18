import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/channel_name.dart';

/// Provides access to the native platform's exit app functionality.
///
/// This plugin allows you to exit your Flutter application using
/// platform-specific native methods instead of calling `exit(0)` in Dart.
class FlutterExitApp {
  FlutterExitApp._();

  /// The method channel used to communicate with native platforms.
  /// Exposed for testing purposes only.
  @visibleForTesting
  static MethodChannel channel = const MethodChannel('flutter_exit_app');

  /// Gets the platform version.
  ///
  /// Returns a string describing the platform version (e.g., "Android 13" or "iOS 16.0").
  /// Returns null if the platform version cannot be determined.
  static Future<String?> get platformVersion async {
    try {
      final String? version = await channel.invokeMethod<String>('getPlatformVersion');
      return version;
    } on PlatformException catch (e) {
      throw Exception('Failed to get platform version: ${e.message}');
    }
  }

  /// Exits the application using platform-specific methods.
  ///
  /// On Android: Finishes the activity and removes it from the task list,
  /// then exits the process after a 1-second delay.
  ///
  /// On iOS: By default, suspends the application (Apple guideline compliant).
  /// If [iosForceExit] is true, the app will terminate the process after
  /// a 1-second delay.
  ///
  /// Returns `true` if the exit was initiated successfully, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// // Standard exit (iOS suspends, Android exits)
  /// await FlutterExitApp.exitApp();
  ///
  /// // Force exit on iOS (not recommended by Apple)
  /// await FlutterExitApp.exitApp(iosForceExit: true);
  /// ```
  ///
  /// **Note**: On iOS, force-exiting is against Apple's Human Interface Guidelines.
  /// Only use [iosForceExit] when absolutely necessary.
  static Future<bool> exitApp({bool iosForceExit = false}) async {
    try {
      final String? res = await channel.invokeMethod<String>(
        ChannelName.exitApp,
        <String, dynamic>{"killIosProcess": iosForceExit},
      );
      return res == "Done";
    } on PlatformException {
      // Log error but return false to indicate failure
      return false;
    } catch (_) {
      return false;
    }
  }
}
