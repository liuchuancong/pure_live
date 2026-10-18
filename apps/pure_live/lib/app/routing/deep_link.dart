/// The `purelive://room` deep link and the launch handoff behind it.
///
/// One parser serves three doors into the same room:
///
/// * **Cold-start deep links** (a browser, a QR scanner, a protocol handler
///   that starts the app): the platform reports the URI to go_router, and
///   [launchDeepLinkRedirect] rewrites it to the room route before any
///   matching happens, so the router's own start-up location never
///   competes with it — go_router only falls back to that when no deep
///   link exists.
/// * **The running desktop instance**: a second launch forwards its
///   arguments over the single-instance channel as a `LaunchIntent`; the
///   router provider (app_router.dart) subscribes to the channel and
///   answers [OpenRoomLink] by pushing the room, wherever the app is.
/// * **The splash window**: an intent that arrives while the splash is still
///   up cannot push yet — the splash's route-on `go` would replace the whole
///   stack and drop it. Those park in [pendingLaunchRoomProvider] and the
///   splash's handover (splash_routes) goes to the launch branch first and
///   pushes the room on top, so a command-line room survives the splash.
///
/// The scheme is this app's own (`purelive`, the one the LAN-sync QR and the
/// desktop protocol registration already speak); the room host spelling
/// `purelive://room?site=&id=` has no counterpart in the 3.x reference — the
/// reference only carries rooms across process launches (`--open-room=`), so
/// the URI grammar is defined here.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:live_shell/live_shell.dart' show LaunchIntent, NewWindow, OpenRoomLink, ShowMainWindow;
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/app/routing/route_paths.dart';

/// One room a deep link or a launch handoff asks to open.
final class RoomDeepLink {
  /// A room link.
  const new({required this.siteId, required this.roomId, this.roomName = ''});

  /// The scheme every deep link of the app speaks.
  static const String scheme = 'purelive';

  /// The host that marks a room link (`purelive://room?...`).
  static const String roomHost = 'room';

  /// The platform the room belongs to.
  final String siteId;

  /// The platform-specific room id.
  final String roomId;

  /// A caller-provided title hint.
  final String roomName;

  /// The link this app would hand out for the room — also the shape the
  /// desktop protocol registration points at the executable.
  Uri toUri() => Uri(
    scheme: RoomDeepLink.scheme,
    host: RoomDeepLink.roomHost,
    queryParameters: {'site': siteId, 'id': roomId, if (roomName.isNotEmpty) 'title': roomName},
  );

  /// Parses a room link, null when [uri] is not one.
  ///
  /// Two spellings are accepted, both with the site and room ids required —
  /// a link without them is noise, and opening the launch page is worse than
  /// ignoring it:
  ///
  /// * `purelive://room?site=bilibili&id=123` — the canonical query form.
  /// * `purelive://room/bilibili/123` — the path form a platform may
  ///   normalise the query into.
  static RoomDeepLink? tryParse(Uri uri) {
    if (uri.scheme.toLowerCase() != scheme) {
      return null;
    }
    final host = uri.host.toLowerCase();
    final query = uri.queryParameters;
    if (host == roomHost) {
      final site = query['site']?.trim();
      final id = query['id']?.trim();
      if (site != null && site.isNotEmpty && id != null && id.isNotEmpty) {
        return RoomDeepLink(siteId: site, roomId: id, roomName: _title(query));
      }
      final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
      if (segments.length >= 2) {
        return RoomDeepLink(siteId: segments[0], roomId: segments[1], roomName: _title(query));
      }
      return null;
    }
    // `purelive:/room/site/id` — a hostless spelling the platform may hand
    // over with the host folded into the path.
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (host.isEmpty && segments.length >= 3 && segments[0] == roomHost) {
      final site = segments[1].trim();
      final id = segments[2].trim();
      if (site.isNotEmpty && id.isNotEmpty) {
        return RoomDeepLink(siteId: site, roomId: id, roomName: _title(query));
      }
    }
    return null;
  }

  static String _title(Map<String, String> query) => query['title'] ?? query['name'] ?? '';

  /// The typed route this link opens.
  RoomRoute toRoute() => RoomRoute(siteId: siteId, roomId: roomId, roomName: roomName);
}

/// The room a launch asked for while the splash was still up, waiting for
/// the splash's handover to place it.
///
/// The reference keeps the same one-slot hand-off
/// (`core/platform/initial_room_handoff.dart`): an offer replaces whatever
/// waited, taking it consumes it, and a take before any offer is simply
/// null — no queue, because only the newest request can matter to a viewer.
final pendingLaunchRoomProvider = NotifierProvider<PendingLaunchRoomNotifier, RoomDeepLink?>(
  PendingLaunchRoomNotifier.new,
);

/// Holds the room the splash's handover still owes the viewer.
final class PendingLaunchRoomNotifier extends Notifier<RoomDeepLink?> {
  @override
  RoomDeepLink? build() => null;

  /// The room waiting for the splash's handover, null when none waits.
  RoomDeepLink? get held => state;

  /// Parks [room] for the splash's handover.
  set held(RoomDeepLink room) => state = room;

  /// Takes the parked room, null when none waited.
  RoomDeepLink? take() {
    final room = state;
    state = null;
    return room;
  }
}

/// The router-level rewrite that turns a cold-start deep link into the room
/// route.
///
/// Installed as the [GoRouter]'s top-level redirect, so it runs before any
/// matching: the incoming `purelive://room` URI normalises to the empty path
/// (the ids live in the host and the query, not the path), which would
/// otherwise silently land on `/`. A non-deep-link location passes through
/// untouched, and the rewrite's own output carries no scheme, so the guard
/// cannot loop.
String? launchDeepLinkRedirect(BuildContext context, GoRouterState state) {
  final room = RoomDeepLink.tryParse(state.uri);
  return room?.toRoute().location;
}

/// Answers one launch request inside the running instance.
///
/// The window is revealed first — a room opened into a hidden window is a
/// taskbar icon that appears to do nothing — then the intent is carried out:
/// a room link pushes over whatever page the app is on (parking for the
/// splash when the splash is still up), and a plain show/navigate request
/// moves the app to its route. File and recorder requests have no
/// destination this layer owns, so they only reveal the window.
Future<void> handleLaunchIntent(Ref ref, GoRouter router, LaunchIntent intent) async {
  final reveal = ref.read(revealMainWindowProvider);
  switch (intent) {
    case OpenRoomLink(:final link):
      final room = RoomDeepLink.tryParse(link);
      if (room == null) {
        await reveal();
        return;
      }
      await reveal();
      await _openRoom(ref, router, room);
    case ShowMainWindow(:final route?):
      await reveal();
      router.go(route);
    case ShowMainWindow():
      await reveal();
    case NewWindow(:final route?):
      // No secondary-window set is wired; the request degenerates to the
      // navigation it was asking the window to show.
      await reveal();
      router.go(route);
    case NewWindow():
      await reveal();
    default:
      // OpenFile and ShowRecorder: import and recording destinations join
      // with their own waves; the launch at least brings the app up.
      await reveal();
  }
}

Future<void> _openRoom(Ref ref, GoRouter router, RoomDeepLink room) async {
  final route = room.toRoute();
  final currentPath = router.routerDelegate.currentConfiguration.uri.path;
  if (currentPath == RoutePath.splash) {
    // The splash's timer will replace the whole stack when it fires; park
    // the room so the handover can place it above the launch branch.
    ref.read(pendingLaunchRoomProvider.notifier).held = room;
    return;
  }
  unawaited(router.push(route.location));
}
