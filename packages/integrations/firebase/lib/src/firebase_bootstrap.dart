// Module: lib/src/firebase_bootstrap.dart
// Purpose: Guarded Firebase start-up: initialize once when the host carries
// options, report an unconfigured status instead of crashing when it does not.
// Author: liuchuancong
// Created: 2026-10-10
//
// v1 wired Firebase at the top of main() with generated options, so a build
// without google-services / GoogleService-Info.plist died before the first
// frame. The shell treats Firebase as an optional accelerator: everything
// here answers a FirebaseStatus, and callers branch on `configured` rather
// than catching.

import 'package:firebase_core/firebase_core.dart';

/// How the Firebase start-up ended.
enum FirebaseBootState { configured, unconfigured, failed }

/// The outcome of one start-up attempt.
final class FirebaseStatus {
  const FirebaseStatus({required this.state, this.appName, this.error});

  final FirebaseBootState state;
  final String? appName;
  final String? error;

  bool get configured => state == FirebaseBootState.configured;
}

/// The start-up guard. One call per process; repeat calls return the recorded
/// status without touching Firebase again.
final class FirebaseBootstrap {
  FirebaseBootstrap._();

  static FirebaseStatus? _status;

  /// The recorded outcome, or null before the first [ensureInitialized].
  static FirebaseStatus? get status => _status;

  static bool get configured => _status?.configured ?? false;

  /// Initializes the default Firebase app when options exist. [options] comes
  /// from the generated firebase_options.dart; when the host passes null the
  /// call relies on platform configuration files and reports unconfigured if
  /// they are absent.
  static Future<FirebaseStatus> ensureInitialized({FirebaseOptions? options}) async {
    final existing = _status;
    if (existing != null) {
      return existing;
    }
    try {
      if (Firebase.apps.isNotEmpty) {
        _status = FirebaseStatus(state: FirebaseBootState.configured, appName: Firebase.apps.first.name);
        return _status!;
      }
      final app = await Firebase.initializeApp(options: options);
      _status = FirebaseStatus(state: FirebaseBootState.configured, appName: app.name);
      return _status!;
    } on FirebaseException catch (error) {
      // The documented unconfigured shapes: "no FirebaseOptions" and
      // "Duplicate app" aside, missing platform config files surface as
      // api-key-absent errors. Unconfigured is a normal state for community
      // builds, not a crash.
      final unconfigured =
          error.code == 'invalid-api-key' ||
          error.code == 'no-options' ||
          '${error.message}'.contains('FirebaseOptions');
      _status = FirebaseStatus(
        state: unconfigured ? FirebaseBootState.unconfigured : FirebaseBootState.failed,
        error: '${error.code}: ${error.message}',
      );
      return _status!;
    } catch (error) {
      _status = FirebaseStatus(state: FirebaseBootState.failed, error: '$error');
      return _status!;
    }
  }
}
