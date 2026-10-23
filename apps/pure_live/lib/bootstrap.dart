import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:live_log/live_log.dart' show ErrorReporter, LiveLog, LoggerConsoleSink;
import 'package:live_platform/live_platform.dart' show FormFactor, PlatformBootstrap, PlatformRuntime;
import 'package:live_shell/live_shell.dart' show RenderFallbacks, WindowHost, WindowRole;
import 'package:live_shell_desktop/live_shell_desktop.dart'
    show WindowManagerHost, configureMainWindow, primaryChromePlan;

import 'package:pure_live/app/startup/startup_coordinator.dart' show runStartup;
import 'package:pure_live/app/theme/system_accent_color.dart' show preloadSystemAccent;

/// What one process boot produced: the platform snapshot and, on a desktop
/// form factor, the main window's host already attached to its events.
final class Boot {
  /// A completed boot.
  const new({required this.runtime, required this.windowHost});

  /// The platform facts and capabilities.
  final PlatformRuntime runtime;

  /// The main window's host, or null where the form factor has no window to
  /// host (a phone, a tablet, a TV).
  final WindowHost? windowHost;
}

/// Boots everything the widget tree cannot build lazily: the platform layer,
/// the log tree, the desktop window's dress and its host, and the startup
/// tasks. A failure here is fatal — the startup error screen replaces the
/// app, because a half-initialised shell is worse than a visible failure.
Future<Boot> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = PlatformBootstrap.init();
  final log = LiveLog.root(sinks: [const LoggerConsoleSink()]);
  final bootLog = log.forCategory('boot');

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorReporter.report(bootLog, details.exception, details.stack, message: 'framework error');
  };

  final formFactor = runtime.environment.runtime.formFactor;
  await runStartup(log: bootLog);
  // The accent read is asynchronous and the theme wants the answer at the
  // first frame, so the preload starts now and the theme factory reads
  // whatever has landed by then.
  if (formFactor == FormFactor.desktop) {
    unawaited(preloadSystemAccent());
    // The window is dressed before the first frame: the hidden caption and
    // the self-drawn strip are a creation-time choice, not a live one.
    await configureMainWindow(
      plan: primaryChromePlan(runtime.environment.runtime.kind),
      role: WindowRole.main,
      fallbacks: const RenderFallbacks(),
      title: 'Pure Live',
      background: const Color(0xFF101418),
    );
    final host = WindowManagerHost(role: WindowRole.main)..attach();
    return Boot(runtime: runtime, windowHost: host);
  }
  return Boot(runtime: runtime, windowHost: null);
}
