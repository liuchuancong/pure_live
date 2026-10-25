import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_shell/live_shell.dart' show WindowRole;

import 'package:pure_live/app/providers/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/app/providers/window_providers.dart' show secondaryWindowsProvider;

/// Opens a complete application clone at the home route. Every desktop
/// window can do this; a phone has no windows and ignores it.
Future<void> openAppWindow(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final desktop = container.read(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.desktop;
  final windows = container.read(secondaryWindowsProvider);
  if (!desktop || windows == null) return;
  try {
    await windows.open(role: WindowRole.panel);
  } on Object {
    // A window that could not be created simply does not appear.
  }
}
