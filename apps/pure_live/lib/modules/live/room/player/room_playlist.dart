import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';

/// The rooms a live room was opened from, in that list's order, and where
/// the room sits among them. The portrait full screen swipes up to the
/// next room and down to the previous, wrapping around at either end.
final class RoomPlaylist {
  RoomPlaylist({required List<LiveRoom> rooms, required this.index}) : rooms = List<LiveRoom>.unmodifiable(rooms);

  /// The playlist [rooms] with [current] in it; null when the list has no
  /// other room or does not contain the room.
  static RoomPlaylist? of(List<LiveRoom> rooms, LiveRoom current) {
    final index = rooms.indexWhere((room) => room.ref.identityKey == current.ref.identityKey);
    if (index < 0 || rooms.length < 2) return null;
    return RoomPlaylist(rooms: rooms, index: index);
  }

  /// The rooms, in the list's order.
  final List<LiveRoom> rooms;

  /// The room shown now.
  final int index;

  /// The room shown now.
  LiveRoom get current => rooms[index];

  /// Whether there is another room to swipe to.
  bool get swipeable => rooms.length > 1;

  /// The room [step] places away (1 the next, -1 the previous), wrapping
  /// around; null when there is nothing to swipe to.
  LiveRoom? neighbour(int step) => swipeable ? rooms[(index + step) % rooms.length] : null;

  /// This playlist moved [step] places.
  RoomPlaylist move(int step) => RoomPlaylist(rooms: rooms, index: (index + step) % rooms.length);
}

/// The source list of the room shown in this app, set when a room is opened
/// from a browsable list and cleared when it is opened any other way.
final class RoomPlaylistController extends Notifier<RoomPlaylist?> {
  @override
  RoomPlaylist? build() => null;

  /// Stores the list [rooms] the room [current] was opened from; a list
  /// without the room, or with only the room itself, leaves nothing to swipe.
  void open({required List<LiveRoom> rooms, required LiveRoom current}) {
    state = RoomPlaylist.of(rooms, current);
  }

  /// Moves [step] places and returns the room there; null when nothing is
  /// stored.
  LiveRoom? move(int step) {
    final playlist = state;
    if (playlist == null || !playlist.swipeable) return null;
    final next = playlist.move(step);
    state = next;
    return next.current;
  }

  /// Forgets the source list.
  void clear() => state = null;

  /// Forgets the source list only when it still shows the room [key]: the
  /// leaving page reads no `ref`, so the comparison runs here.
  ///
  /// The leaving page is unmounted while the tree is being torn down, and
  /// Riverpod rejects a notification in that phase (it left the page half
  /// unmounted and the route transition's Hero lookup reading a dead element).
  /// The write therefore waits for the frame, and re-checks: a room opened
  /// meanwhile owns the list now.
  void clearIfCurrent(String key) {
    if (state?.current.ref.identityKey != key) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (ref.mounted && state?.current.ref.identityKey == key) clear();
    });
  }
}

/// The current room's source list.
final roomPlaylistProvider = NotifierProvider<RoomPlaylistController, RoomPlaylist?>(RoomPlaylistController.new);
