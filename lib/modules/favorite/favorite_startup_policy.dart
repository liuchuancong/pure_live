import 'package:pure_live/common/models/live_room.dart';

/// Invalidates the live/offline bit persisted by a previous process before a
/// new launch starts its network verification.
///
/// Metadata such as title, cover and tags remains available, but an ended
/// stream can no longer be painted as live while the first refresh is still in
/// flight or when that refresh fails.
List<LiveRoom> markFavoriteRoomsPendingVerification(Iterable<LiveRoom> rooms) {
  return rooms.map((room) => room.copyWith(status: false, liveStatus: LiveStatus.unknown)).toList(growable: false);
}

String favoriteRoomIdentity(LiveRoom room) => '${room.platform?.toLowerCase() ?? ''}:${room.roomId ?? ''}';

/// Merges room-detail responses into the latest user-owned favourites
/// snapshot. Tags and reliable audience fields come from the latest snapshot,
/// so an in-flight refresh never restores a removed room or discards edits.
({List<LiveRoom> rooms, bool changed}) mergeFavoriteRoomUpdates(
  Iterable<LiveRoom> currentRooms,
  Map<String, LiveRoom> updates,
) {
  var changed = false;
  final rooms = currentRooms
      .map((previous) {
        final updated = updates[favoriteRoomIdentity(previous)];
        if (updated == null) return previous;
        changed = true;
        return updated.copyWith(tagIds: List<String>.from(previous.tagIds)).withAudienceFallbackFrom(previous);
      })
      .toList(growable: false);
  return (rooms: rooms, changed: changed);
}

/// Builds the single snapshot published after a startup verification pass.
/// Failed rooms become unknown, successful rooms use fresh server data, and
/// local tags/audience fallbacks continue to come from the latest user-owned
/// favourites list.
List<LiveRoom> buildVerifiedFavoriteSnapshot(Iterable<LiveRoom> currentRooms, Map<String, LiveRoom> successfulUpdates) {
  final pending = markFavoriteRoomsPendingVerification(currentRooms);
  return mergeFavoriteRoomUpdates(pending, successfulUpdates).rooms;
}
