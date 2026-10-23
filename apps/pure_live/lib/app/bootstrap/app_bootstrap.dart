import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:live_log/live_log.dart' show ErrorReporter, LiveLog, LoggerConsoleSink;
import 'package:live_platform/live_platform.dart' show FormFactor, PlatformBootstrap, PlatformRuntime;
import 'package:live_shell/live_shell.dart' show RenderFallbacks, WindowEvent, WindowHost, WindowRole;
import 'package:live_shell_desktop/live_shell_desktop.dart'
    show WindowManagerHost, configureMainWindow, primaryChromePlan;
import 'package:live_storage/live_storage.dart'
    show StorageAdapterRegistry, StorageBootstrap, StoragePathProvider, StoragePrefs;
import 'package:pure_live/app/theme/system_accent_color.dart' show preloadSystemAccent;
import 'package:pure_live/infrastructure/storage/storage_paths.dart' show StoragePaths;

/// What one process boot produced: the platform snapshot, the resolved
/// storage layout and, on a desktop form factor, the main window's host
/// with its close policy armed.
final class Boot {
  /// A completed boot.
  const Boot({required this.runtime, required this.windowHost, required this.storagePaths}) : error = null;

  /// A failed boot; [error] is what the wiring threw.
  const Boot.failure({required this.runtime, required this.error}) : windowHost = null, storagePaths = null;

  /// The platform facts and capabilities.
  final PlatformRuntime runtime;

  /// The main window's host, or null where the form factor has no window
  /// to host (a phone, a tablet, a TV).
  final WindowHost? windowHost;

  /// The resolved storage layout; null only on a failed boot.
  final StoragePaths? storagePaths;

  /// The failure, when [storagePaths] is null.
  final Object? error;

  /// Whether the boot failed and the error screen must show instead.
  bool get failed => storagePaths == null;
}

/// Boots everything the widget tree cannot build lazily: the platform
/// layer, the log tree, the accent preload, the desktop window's dress and
/// its host with the close policy, the storage layout, and — best-effort —
/// the Hive storage over it.
///
/// A failure here is fatal — the startup error screen replaces the app,
/// because a half-initialised shell is worse than a visible failure.
Future<Boot> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = PlatformBootstrap.init(appNamespace: 'pure_live');
  final log = LiveLog.root(sinks: const [LoggerConsoleSink()]);
  final bootLog = log.forCategory('boot');

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorReporter.report(bootLog, details.exception, details.stack, message: 'framework error');
  };

  try {
    // The accent read is asynchronous and the theme pair is built from it,
    // so it lands before the first frame instead of recolouring afterwards.
    unawaited(preloadSystemAccent());
    final formFactor = runtime.environment.runtime.formFactor;
    WindowHost? windowHost;
    if (formFactor == FormFactor.desktop) {
      // The window is dressed before the first frame: the hidden caption
      // and the self-drawn strip are a creation-time choice, not a live
      // one.
      await configureMainWindow(
        plan: primaryChromePlan(runtime.environment.runtime.kind),
        role: WindowRole.main,
        fallbacks: const RenderFallbacks(),
        title: 'Pure Live',
        background: const Color(0xFF101418),
      );
      final host = WindowManagerHost(role: WindowRole.main)..attach();
      await host.setPreventClose(enabled: true);
      _wireClosePolicy(host, log.forCategory('close'));
      windowHost = host;
    }
    final storagePaths = await StoragePaths.resolve(environment: runtime.environment, log: bootLog);
    // The storage layer is best-effort: a failure logs and the boot carries
    // on — browsing works without storage, and the providers fall back to
    // their defaults when the settings facade never opened.
    try {
      final storageBootstrap = StorageBootstrap(
        pathProvider: StoragePathProvider(resolver: () async => storagePaths.data.path),
        adapterRegistry: StorageAdapterRegistry(), // plain JSON values need no custom adapter
      );
      await storageBootstrap.initialize();
      await StoragePrefs.init();
    } on Object catch (error, stackTrace) {
      log.forCategory('storage').error('storage bootstrap failed', error: error, stackTrace: stackTrace);
    }
    return Boot(runtime: runtime, windowHost: windowHost, storagePaths: storagePaths);
  } on Object catch (error, stackTrace) {
    bootLog.fatal('boot failed', error: error, stackTrace: stackTrace);
    return Boot.failure(runtime: runtime, error: error);
  }
}

/// The close policy until the settings screen owns one: a close request
/// quits — the window is destroyed, which ends the process. The tray and
/// the remembered hide-to-tray answer arrive with the tray wiring.
void _wireClosePolicy(WindowHost host, LiveLog log) {
  host.events.listen((event) {
    if (event == WindowEvent.closeRequested) {
      log.info('close requested; quitting');
      unawaited(host.destroy());
    }
  });
}
