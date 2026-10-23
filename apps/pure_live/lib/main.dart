import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/bootstrap/app_bootstrap.dart' show bootstrap;
import 'package:pure_live/app/bootstrap/pure_live_app.dart' show PureLiveApp;
import 'package:pure_live/app/bootstrap/startup_error_page.dart' show StartupErrorPage;
import 'package:pure_live/app/providers/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/app/providers/storage_providers.dart' show storagePathsProvider;
import 'package:pure_live/app/providers/window_providers.dart' show windowHostProvider;

/// The process entry point: run the boot the bootstrap owns, then hand the
/// boot's facts to the widget tree through `ProviderScope` overrides. A
/// failed boot shows the start-up error screen instead of the app.
Future<void> main() async {
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
      ],
      child: const PureLiveApp(),
    ),
  );
}
