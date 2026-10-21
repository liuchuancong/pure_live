import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_live/system/navigation/app_router.dart' show RoomRoute;

/// The rooms a live room was opened from, in that list's order, and where the
/// open room sits among them.
///
/// The player offers the previous and next room from it; a room opened on its
/// own — a deep link, the clipboard, a web search hit — has a playlist of one
/// and therefore no switch.
final class RoomPlaylist {
  /// The list with [current] in it; a room missing from the list goes first.
  factory(List<LiveRoom> rooms, {required LiveRoom current}) {
    final index = rooms.indexWhere((room) => sameRoom(room, current));
    return index < 0 ? RoomPlaylist._([current, ...rooms], 0) : RoomPlaylist._(rooms, index);
  }

  new _(List<LiveRoom> rooms, this.index) : rooms = List.unmodifiable(rooms);

  /// The rooms, in their page's order.
  final List<LiveRoom> rooms;

  /// The position of the room shown now.
  final int index;

  /// The room shown now.
  LiveRoom get currentRoom => rooms[index];

  /// Whether there is another room to switch to (a lone room has none).
  bool get switchable => rooms.length > 1;

  /// The room [step] places away (1 the next, -1 the previous), wrapping at
  /// either end; null when there is nothing to switch to.
  LiveRoom? neighbour(int step) {
    if (!switchable) {
      return null;
    }
    return rooms[(index + step) % rooms.length];
  }

  /// This list with [room] current.
  RoomPlaylist movedTo(LiveRoom room) => RoomPlaylist(rooms, current: room);

  /// Whether [a] and [b] are the same room on the same platform.
  static bool sameRoom(LiveRoom a, LiveRoom b) => a.ref.platform == b.ref.platform && a.ref.roomId == b.ref.roomId;
}

/// The playlist the open room was entered from; null outside a room.
final roomPlaylistProvider = NotifierProvider<RoomPlaylistNotifier, RoomPlaylist?>(RoomPlaylistNotifier.new);

/// Holds [RoomPlaylist] for the room on screen.
final class RoomPlaylistNotifier extends Notifier<RoomPlaylist?> {
  @override
  RoomPlaylist? build() => null;

  /// The list [current] was opened from.
  void open(List<LiveRoom> rooms, LiveRoom current) => state = RoomPlaylist(rooms, current: current);

  /// Moves to [room]; the caller navigates.
  void movedTo(LiveRoom room) {
    final playlist = state;
    if (playlist != null) {
      state = playlist.movedTo(room);
    }
  }
}

/// Opens [current] with [rooms] as its switch context — the one way a list
/// page opens a room.
Future<void> openRoomWithPlaylist(BuildContext context, WidgetRef ref, List<LiveRoom> rooms, LiveRoom current) async {
  ref.read(roomPlaylistProvider.notifier).open(rooms, current);
  await RoomRoute(
    siteId: current.ref.platform,
    roomId: current.ref.roomId,
    roomName: current.content.title,
  ).push<void>(context);
}

/// Switches the open room [step] places away: the position moves first, then
/// the room route replaces itself, so back still returns to the list that
/// opened it.
void switchRoom(BuildContext context, WidgetRef ref, int step) {
  final playlist = ref.read(roomPlaylistProvider);
  final next = playlist?.neighbour(step);
  if (playlist == null || next == null) {
    return;
  }
  ref.read(roomPlaylistProvider.notifier).movedTo(next);
  RoomRoute(siteId: next.ref.platform, roomId: next.ref.roomId, roomName: next.content.title).pushReplacement(context);
}
