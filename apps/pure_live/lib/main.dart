import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/app/pure_live_app.dart';
import 'package:pure_live/app/startup/startup_error_page.dart' show StartupErrorPage;
import 'package:pure_live/bootstrap.dart';

/// The process entry point: boot the platform layer and the service graph,
/// then hand the boot's facts to the widget tree through `ProviderScope`
/// overrides — only the bootstrap can produce them, so everything
/// downstream reads them as plain providers.
///
/// A failed boot shows the start-up error screen instead of the app.
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
        appServicesProvider.overrideWithValue(boot.services!),
      ],
      child: const PureLiveApp(),
    ),
  );
}
