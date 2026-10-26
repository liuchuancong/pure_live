import 'dart:async' show unawaited;
import 'dart:io' show Directory;

import 'package:flutter/widgets.dart';
import 'package:live_log/live_log.dart' show ErrorReporter;
import 'package:live_platform/live_platform.dart' show FormFactor, PlatformBootstrap, PlatformRuntime;
import 'package:live_storage/live_storage.dart' show StorageBootstrap, StoragePathProvider, StoragePrefs;
import 'package:path/path.dart' as p;
import 'package:pure_live/app/logging/app_log.dart' show appLog, initAppLog;
import 'package:pure_live/app/providers/providers.dart';
import 'package:pure_live/app/theme/fonts/font_library.dart' show CloudFontIds, FontLibrary;
import 'package:pure_live/app/theme/settings/system_accent_color.dart' show preloadSystemAccent;
import 'package:pure_live/infrastructure/infrastructure.dart';
import 'package:pure_live/shared/shared.dart';

/// What one process boot produced: the platform snapshot, the resolved
/// storage layout, and the error when the boot failed.
///
/// Windows, window hosts and tray wiring are no longer part of the boot: with
/// `multiview_desktop` every window is a view in this one engine, and the
/// primary's shell starts from the window root once the first frame exists.
final class Boot {
  /// A completed boot.
  const Boot({required this.runtime, required this.storagePaths}) : error = null;

  /// A failed boot; [error] is what the wiring threw.
  const Boot.failure({required this.runtime, required this.error}) : storagePaths = null;

  /// The platform facts and capabilities.
  final PlatformRuntime runtime;

  /// The resolved storage layout; null only on a failed boot.
  final StoragePaths? storagePaths;

  /// The failure, when [storagePaths] is null.
  final Object? error;

  /// Whether the boot failed and the error screen must show instead.
  bool get failed => storagePaths == null;
}

/// Boots everything the widget tree cannot build lazily: the platform layer,
/// the log tree, the accent preload, the storage layout, and — best-effort —
/// the SQLite storage over it.
///
/// A failure here is fatal — the startup error screen replaces the app,
/// because a half-initialised shell is worse than a visible failure.
Future<Boot> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A TV build is chosen at build time (`--dart-define=PURE_LIVE_TV=true`
  // on the leanback package): the leanback launcher cannot reach a touch
  // UI, so the shell must come up in its TV shape from the first frame.
  final runtime = PlatformBootstrap.init(
    appNamespace: 'pure_live',
    // The null branch keeps the platform's own answer (the lint knows the
    // parameter default; the ternary stays because the TV side is not a
    // literal default).
    // ignore: avoid_redundant_argument_values
    formFactor: const bool.fromEnvironment('PURE_LIVE_TV') ? FormFactor.tv : null,
  );
  final log = appLog;
  final bootLog = log.forCategory('boot');

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorReporter.report(log.forCategory('errors'), details.exception, details.stack, message: 'framework error');
  };
  // Async errors outside a widget's zone would otherwise only reach the
  // console; they belong in the same diagnostic stream.
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    log.forCategory('errors').error('uncaught asynchronous error', error: error, stackTrace: stack);
    return true;
  };

  try {
    // The accent read is asynchronous and the theme pair is built from it,
    // so it lands before the first frame instead of recolouring afterwards.
    unawaited(preloadSystemAccent());
    // The player's native engine loads once, before any room asks for it;
    // the OS playback surfaces (SMTC, the Android notification) arm right
    // after — a failure here only costs the controls, never the app.
    primePlayerEngine();
    unawaited(enableMediaSession());
    // Job outcomes (a finished or failed recording) reach the system tray;
    // the permission is asked when a job starts, not here.
    unawaited(enableUserNotifications());
    final storagePaths = await StoragePaths.resolve(environment: runtime.environment, log: bootLog);
    // The cloud font snapshot is a plain folder scan and stays synchronous:
    // the theme validates its stored family before the first frame, and a
    // downloaded family must answer that check on the very first read. The
    // data folder is the pre-shared-download location; both are scanned so
    // an upgrade keeps every installed family.
    CloudFontIds.replace(
      FontLibrary.scanInstalledRoots([
        Directory(p.join(storagePaths.data.path, 'fonts')),
        fontsRootOf(defaultDownloadRoot(storagePaths)),
      ]),
    );
    // The storage layer is best-effort: a failure logs and the boot carries
    // on — browsing works without storage, and the providers fall back to
    // their defaults when the SQLite database never opened.
    try {
      final storageBootstrap = StorageBootstrap(
        pathProvider: StoragePathProvider(resolver: () async => storagePaths.data.path),
      );
      await storageBootstrap.initialize();
      await StoragePrefs.init();
      // A custom download folder moves the fonts with it; the pre-prefs scan
      // above could not know the choice, so fold its families in now.
      refreshCloudFontSnapshot();
      initAppLog(directory: Directory(p.join(storagePaths.data.path, 'logs')));
      bootLog.info('storage ready', fields: {'data': storagePaths.data.path});
    } on Object catch (error, stackTrace) {
      log.forCategory('storage').error('storage bootstrap failed', error: error, stackTrace: stackTrace);
    }
    // Network images need their cache folder before the first frame; the
    // folder is independent of whether the data store opened.
    await prepareImageCache();
    return Boot(runtime: runtime, storagePaths: storagePaths);
  } on Object catch (error, stackTrace) {
    bootLog.fatal('boot failed', error: error, stackTrace: stackTrace);
    return Boot.failure(runtime: runtime, error: error);
  }
}
