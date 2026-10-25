import 'package:desktop_multi_window/desktop_multi_window.dart' show WindowController;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_shell/live_shell.dart' show WindowRole;
import 'package:live_shell_desktop/live_shell_desktop.dart' show DesktopSecondaryWindow, WindowArguments;

import 'package:pure_live/app/providers/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/app/providers/shell_settings_provider.dart' show roomWindowsProvider;
import 'package:pure_live/app/providers/window_providers.dart' show secondaryWindowsProvider;
import 'package:pure_live/app/providers/window_storage_bridge.dart' show WindowStorageMethods;
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute;

/// Opens a live room the host's way: in its own window on the desktop —
/// the chat app's shape, one window per room the viewer is watching — or
/// pushed onto the app's navigator everywhere else, and on the desktop too
/// whenever the viewer turned the windowed rooms off or the window could
/// not be created.
Future<void> openRoom(BuildContext context, {required String platform, required String roomId}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final desktop = container.read(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.desktop;
  final windows = container.read(secondaryWindowsProvider);
  if (desktop && container.read(roomWindowsProvider) && windows != null) {
    final route = '/room/${Uri.encodeComponent(platform)}/${Uri.encodeComponent(roomId)}';
    try {
      // One window per room: a second window would show the same room's
      // player and chat twice, so an already-open room comes forward
      // instead of opening again.
      for (final window in windows.opened) {
        if (window is! DesktopSecondaryWindow) continue;
        final arguments = WindowArguments.fromRaw(window.controller.arguments);
        if (arguments.role == WindowRole.panel && arguments.route == route) {
          if (await _raiseAt(window.controller, route)) return;
          windows.noteGone(window.id);
        }
      }
      // A room may have been opened by another window; the process-wide
      // list catches it, while `windows.opened` only knows this window's
      // own creations.
      try {
        for (final controller in await WindowController.getAll()) {
          final arguments = WindowArguments.fromRaw(controller.arguments);
          if (arguments.role == WindowRole.panel && arguments.route == route) {
            if (await _raiseAt(controller, route)) return;
          }
        }
      } on Object {
        // The plugin list failed; opening a new window is the fallback.
      }
      await windows.open(role: WindowRole.panel, route: route);
      return;
    } on Object {
      // The window did not come up; the in-app route still works.
    }
  }
  if (!context.mounted) {
    return;
  }
  await context.push(RoomRoute(platform: platform, roomId: roomId).location);
}

/// Brings [controller]'s window forward at [route].
///
/// The room window may have navigated home since it opened; its launch
/// arguments still name the room, so raising it alone would show the wrong
/// page. The target navigates only when its current location differs, so an
/// already-visible room is not reloaded.
Future<bool> _raiseAt(WindowController controller, String route) async {
  try {
    await controller
        .invokeMethod<Object>(WindowStorageMethods.navigate, {'route': route})
        .timeout(const Duration(milliseconds: 800));
  } on Object {
    // A window from a build without the verb still comes forward.
  }
  try {
    await controller.show().timeout(const Duration(seconds: 1));
    return true;
  } on Object {
    return false;
  }
}
