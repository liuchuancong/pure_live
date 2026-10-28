import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_shell/live_shell.dart' show WindowRole;
import 'package:live_shell_desktop/live_shell_desktop.dart' show DesktopMessageBus, DesktopNavigate;
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:multiview_desktop/multiview_desktop.dart' show MultiViewDesktop;

import 'package:pure_live/app/app.dart';
import 'package:pure_live/modules/live/room/room.dart';

/// Opens a live room the host's way: in its own window on the desktop —
/// the chat app's shape, one window per room the viewer is watching — or
/// pushed onto the app's navigator everywhere else, and on the desktop too
/// whenever the viewer turned the windowed rooms off or the window could
/// not be created.
///
/// Every desktop window shares this isolate, so the registry is the complete
/// answer to "is this room already open": a second window would show the
/// same room's player and chat twice, so an already-open room is navigated
/// and raised instead of opened again.
///
/// [playlist] is the list the viewer picked the room from, in its order:
/// the portrait full screen swipes through it. A room opened any other way
/// leaves no list behind.
Future<void> openRoom(
  BuildContext context, {
  required String platform,
  required String roomId,
  List<LiveRoom>? playlist,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final identityPlatform = platform.trim().toLowerCase();
  final identityRoomId = roomId.trim();
  final index = playlist == null
      ? -1
      : playlist.indexWhere((room) => room.ref.platform == identityPlatform && room.ref.roomId == identityRoomId);
  if (playlist == null || index < 0) {
    container.read(roomPlaylistProvider.notifier).clear();
  } else {
    container.read(roomPlaylistProvider.notifier).open(rooms: playlist, current: playlist[index]);
  }
  final desktop = container.read(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.desktop;
  final windows = container.read(secondaryWindowsProvider);
  if (desktop && container.read(roomWindowsProvider) && windows != null) {
    final route = '/room/${Uri.encodeComponent(platform)}/${Uri.encodeComponent(roomId)}';
    final businessKey = '$identityPlatform/$identityRoomId';
    try {
      final existing = container.read(desktopWindowRegistryProvider).byBusinessKey(businessKey);
      if (existing != null) {
        // Its own router may have navigated away since it opened; the
        // record's route is where the room lives, so it is sent the target
        // rather than only raised.
        DesktopMessageBus.instance.send(existing.viewId, DesktopNavigate(route));
        MultiViewDesktop.fromId(existing.viewId)
          ..show()
          ..focus();
        return;
      }
      await windows.open(role: WindowRole.panel, route: route, businessKey: businessKey);
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
