import 'package:flutter/widgets.dart';
import 'package:live_log/live_log.dart' show ErrorReporter, LiveLog, LoggerConsoleSink;
import 'package:live_platform/live_platform.dart' show FormFactor, PlatformBootstrap, PlatformRuntime;
import 'package:live_shell/live_shell.dart' show RenderFallbacks, WindowHost, WindowRole;
import 'package:live_shell_desktop/live_shell_desktop.dart'
    show WindowManagerHost, configureMainWindow, primaryChromePlan;

import 'package:pure_live/app/app_services.dart' show AppServices;
import 'package:pure_live/app/startup/startup_coordinator.dart' show runStartup;

/// What one process boot produced: the platform snapshot, the wired
/// services and, on a desktop form factor, the main window's host.
final class Boot {
  /// A completed boot.
  const new({required this.runtime, required this.windowHost, required this.services}) : error = null;

  /// A failed boot; [error] is what the wiring threw.
  const new failure({required this.runtime, required this.error}) : windowHost = null, services = null;

  /// The platform facts and capabilities.
  final PlatformRuntime runtime;

  /// The main window's host, or null where the form factor has no window to
  /// host (a phone, a tablet, a TV).
  final WindowHost? windowHost;

  /// The wired services; null only on a failed boot.
  final AppServices? services;

  /// The failure, when [services] is null.
  final Object? error;

  /// Whether the boot failed and the error screen must show instead.
  bool get failed => services == null;
}

/// Boots everything the widget tree cannot build lazily: the platform layer,
/// the log tree, the service graph (paths, storage, documents, sites), the
/// desktop window's dress and its host, and the accent preload.
///
/// A failure here is fatal — the startup error screen replaces the app,
/// because a half-initialised shell is worse than a visible failure.
Future<Boot> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = PlatformBootstrap.init();
  final log = LiveLog.root(sinks: const [LoggerConsoleSink()]);
  final bootLog = log.forCategory('boot');

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorReporter.report(bootLog, details.exception, details.stack, message: 'framework error');
  };

  try {
    await runStartup(log: bootLog);
    final formFactor = runtime.environment.runtime.formFactor;
    WindowHost? windowHost;
    if (formFactor == FormFactor.desktop) {
      // The window is dressed before the first frame: the hidden caption
      // and the self-drawn strip are a creation-time choice, not a live one.
      await configureMainWindow(
        plan: primaryChromePlan(runtime.environment.runtime.kind),
        role: WindowRole.main,
        fallbacks: const RenderFallbacks(),
        title: 'Pure Live',
        background: const Color(0xFF101418),
      );
      windowHost = WindowManagerHost(role: WindowRole.main)..attach();
    }
    final services = await AppServices.boot(log: log, runtime: runtime);
    return Boot(runtime: runtime, windowHost: windowHost, services: services);
  } on Object catch (error, stackTrace) {
    bootLog.fatal('boot failed', error: error, stackTrace: stackTrace);
    return Boot.failure(runtime: runtime, error: error);
  }
}
