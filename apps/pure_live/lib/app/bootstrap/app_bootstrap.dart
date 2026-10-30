import 'dart:async' show unawaited;
import 'dart:io' show HttpOverrides;

import 'package:flutter/widgets.dart';
import 'package:live_log/live_log.dart' show ErrorReporter;
import 'package:live_platform/live_platform.dart' show FormFactor, PlatformBootstrap, PlatformRuntime;
import 'package:live_storage/live_storage.dart' show StorageBootstrap, StoragePathProvider, StoragePrefs;
import 'package:pure_live/app/bootstrap/proxy_http_overrides.dart' show AppProxyHttpOverrides;
import 'package:pure_live/app/logging/app_log.dart' show appLog, initAppLog;
import 'package:pure_live/app/logging/media_core_log_bridge.dart' show installMediaCoreLogBridge;
import 'package:pure_live/app/providers/providers.dart';
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
  // Every `dart:io` HTTP client the process builds — including the ones inside
  // third-party packages that never see the app's own transport — follows the
  // proxy the viewer set. The lookup itself lands with the first window.
  HttpOverrides.global = AppProxyHttpOverrides();
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
    // A layout failure names itself ("A RenderFlex overflowed by 7.0 pixels on
    // the bottom") and nothing else: which widget, with which constraints, is
    // only in the framework's own diagnostics. Logged without them the report
    // is a line nobody can act on.
    ErrorReporter.report(
      log.forCategory('errors'),
      details.exception,
      details.stack,
      message: 'framework error',
      fields: {'diagnostics': _frameworkDiagnostics(details)},
    );
  };
  // Async errors outside a widget's zone would otherwise only reach the
  // console; they belong in the same diagnostic stream.
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    log.forCategory('errors').error('uncaught asynchronous error', error: error, stackTrace: stack);
    return true;
  };

  try {
    // The kernel's log hub feeds the app's tree from before its first
    // engine load, so boot-time playback decisions are on the record too.
    installMediaCoreLogBridge();
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
    // One vocabulary for every folder the app writes; the boot hands its
    // members to the layers that cannot take a provider (logging, the
    // singleton caches), the providers carry it to everything else.
    final appPaths = AppPaths(storagePaths);
    // The storage layer is best-effort: a failure logs and the boot carries
    // on — browsing works without storage, and the providers fall back to
    // their defaults when the SQLite database never opened.
    try {
      final storageBootstrap = StorageBootstrap(
        pathProvider: StoragePathProvider(resolver: () async => storagePaths.data.path),
      );
      await storageBootstrap.initialize();
      await StoragePrefs.init();
      initAppLog(directory: appPaths.logs);
      // The cover cache follows the layout, including a folder the viewer
      // moved. It is read once here because the manager is built against one
      // root; a change lands on the next start.
      installImageCacheRoot(AppFolders(appPaths, readStorageFolderOverrides()).imageCache);
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

/// The first [limit] lines of a framework error's own diagnostics, joined for
/// one log line: for a layout failure these name the widget that built the
/// failing render object, which the exception text alone never does.
String _frameworkDiagnostics(FlutterErrorDetails details, {int limit = 8}) {
  final reported =
      (details.informationCollector?.call() ?? const Iterable<Object?>.empty())
          .map((line) => line.toString().trim())
          .where((line) => line.isNotEmpty)
          .take(limit)
          .join(' | ');
  if (reported.isNotEmpty) return reported;
  return details.context?.toString() ?? details.library ?? 'no diagnostics';
}
