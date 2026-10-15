import 'dart:io' show Platform, exit;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_log/live_log.dart' show ErrorReporter;
import 'package:live_platform/live_platform.dart' show PlatformKind;

import 'package:pure_live/app/app.dart';
import 'package:pure_live/app/composition/app_services.dart';
import 'package:pure_live/app/logging/app_log.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/theme/app_theme.dart';
import 'package:pure_live/platforms/desktop/entry/desktop_entry.dart';
import 'package:pure_live/platforms/desktop/entry/desktop_launch.dart';

/// The process entry point: open the log, boot the service graph, then hand
/// it to the widget tree through `ProviderScope` overrides.
///
/// The log opens first — a boot failure needs somewhere to land — and the
/// framework and zone error hooks report through it. This is the only place
/// composition happens; nothing below the scope reads `AppServices`
/// directly, so a second window can boot its own graph through the same
/// door.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final log = AppLog();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorReporter.report(log.forCategory('flutter'), details.exception, details.stack, message: 'framework error');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorReporter.report(log.forCategory('uncaught'), error, stack);
    return true;
  };

  // The single-instance lock is the first thing a desktop launch takes: a
  // second launch that reached the data tree would fight the running
  // instance over its box locks. A forwarded launch exits here, having
  // already handed its request to whoever holds the port.
  final onDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  final channel = onDesktop ? await acquireDesktopInstance(log: log.root, args: args) : null;
  if (onDesktop && channel == null) {
    // Handed over — this process was only ever a messenger. Nothing past
    // the log has been initialised, so a plain exit loses nothing; a bare
    // return would leave the engine, and the process, alive.
    exit(0);
  }

  final services = await AppServices.boot(log: log);

  // The desktop window's life starts before the first frame (size, title,
  // tray, close interception) and its quit runs the app's own shutdown.
  DesktopEntry? desktopEntry;
  final kind = services.environment.runtime.kind;
  if (kind == PlatformKind.windows || kind == PlatformKind.macos || kind == PlatformKind.linux) {
    desktopEntry = DesktopEntry(
      kind: kind,
      onQuitRequest: () async {
        await channel?.dispose();
        await services.shutdown();
      },
      preferences: services.shell,
      log: log.forCategory('shell'),
    );
    await desktopEntry.prepare();
  }

  runApp(
    ProviderScope(
      overrides: [
        environmentProvider.overrideWithValue(services.environment),
        pathsProvider.overrideWithValue(services.paths),
        storageProvider.overrideWithValue(services.storage),
        sitesProvider.overrideWithValue(services.sites),
        appearanceStoreProvider.overrideWithValue(services.appearance),
        shellPreferencesProvider.overrideWithValue(services.shell),
      ],
      child: AppTheme(diagnostics: log.uiSink, child: const PureLiveApp()),
    ),
  );
}
