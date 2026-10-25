import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/bootstrap/app_bootstrap.dart' show bootstrap;
import 'package:pure_live/app/bootstrap/clone_window.dart' show runCloneWindow;
import 'package:pure_live/app/bootstrap/pure_live_app.dart' show PureLiveApp;
import 'package:pure_live/app/bootstrap/startup_error_page.dart' show StartupErrorPage;
import 'package:pure_live/app/providers/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/app/providers/storage_providers.dart' show storagePathsProvider;
import 'package:pure_live/app/providers/window_providers.dart' show secondaryWindowsProvider, windowHostProvider;

/// The process entry point — every engine runs it, so the first thing it
/// asks is which engine this is.
///
/// The main window comes up through the boot the bootstrap owns, handing
/// the boot's facts to the widget tree through `ProviderScope` overrides
/// (a failed boot shows the start-up error screen instead of the app). A
/// secondary engine — the plugin's `multi_window` arguments — boots a full
/// application clone: the same router and pages, with a remote projection
/// of the primary window's database.
Future<void> main(List<String> arguments) async {
  if (arguments case ['multi_window', _, final rawArguments]) {
    await runCloneWindow(rawArguments);
    return;
  }
  final boot = await bootstrap();
  if (boot.failed) {
    runApp(StartupErrorPage(error: boot.error!));
    return;
  }
  runApp(
    ProviderScope(
      overrides: [
        platformRuntimeProvider.overrideWithValue(boot.runtime),
        windowHostProvider.overrideWithValue(boot.windowHost),
        storagePathsProvider.overrideWithValue(boot.storagePaths!),
        secondaryWindowsProvider.overrideWithValue(boot.secondaryWindows),
      ],
      child: const PureLiveApp(),
    ),
  );
}
