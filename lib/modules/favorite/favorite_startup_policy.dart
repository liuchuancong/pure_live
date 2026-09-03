import 'package:pure_live/common/models/live_room.dart';

/// A transient, non-persisted snapshot used while launch-time verification is
/// in flight.
///
/// Every room is marked [LiveStatus.unknown], so cached state is never
/// presented as current. The three buckets retain their previous positions,
/// however, which prevents the grid from disappearing and reappearing while
/// several platform requests settle.
class FavoriteVerificationPreview {
  FavoriteVerificationPreview._({
    required List<LiveRoom> rooms,
    required List<LiveRoom> onlineRooms,
    required List<LiveRoom> replayRooms,
    required List<LiveRoom> offlineRooms,
  }) : rooms = List<LiveRoom>.unmodifiable(rooms),
       onlineRooms = List<LiveRoom>.unmodifiable(onlineRooms),
       replayRooms = List<LiveRoom>.unmodifiable(replayRooms),
       offlineRooms = List<LiveRoom>.unmodifiable(offlineRooms);

  final List<LiveRoom> rooms;
  final List<LiveRoom> onlineRooms;
  final List<LiveRoom> replayRooms;
  final List<LiveRoom> offlineRooms;
}

/// Invalidates the live/offline bit persisted by a previous process before a
/// new launch starts its network verification.
///
/// Metadata such as title, cover and tags remains available, but an ended
/// stream can no longer be painted as live while the first refresh is still in
/// flight or when that refresh fails.
List<LiveRoom> markFavoriteRoomsPendingVerification(Iterable<LiveRoom> rooms) {
  return rooms
      .map((room) => room.copyWith(status: false, liveStatus: LiveStatus.unknown))
      .toList(growable: false);
}

FavoriteVerificationPreview buildFavoriteVerificationPreview(Iterable<LiveRoom> rooms) {
  final persisted = List<LiveRoom>.from(rooms);
  final pending = markFavoriteRoomsPendingVerification(persisted);
  final online = <LiveRoom>[];
  final replay = <LiveRoom>[];
  final offline = <LiveRoom>[];

  for (var index = 0; index < persisted.length; index++) {
    final previous = persisted[index];
    final preview = pending[index];
    if (previous.effectiveLiveStatus == LiveStatus.replay) {
      replay.add(preview);
    } else if (previous.isLiveNow) {
      online.add(preview);
    } else {
      offline.add(preview);
    }
  }

  return FavoriteVerificationPreview._(
    rooms: pending,
    onlineRooms: online,
    replayRooms: replay,
    offlineRooms: offline,
  );
}

String favoriteRoomIdentity(LiveRoom room) => room.identityKey;

/// Keeps local favourite identity stable when a platform response exposes a
/// different canonical/live-session id. The fresh id is useful inside a full
/// room detail, but replacing the persisted key would detach local tags and
/// make the in-flight result miss its merge target.
LiveRoom bindFavoriteRefreshResultToRequest(LiveRoom requested, LiveRoom refreshed) {
  return refreshed.copyWith(
    roomId: requested.normalizedRoomId,
    platform: requested.normalizedPlatformId,
  );
}

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
        return updated
            .copyWith(tagIds: List<String>.from(previous.tagIds))
            .withAudienceFallbackFrom(previous);
      })
      .toList(growable: false);
  return (rooms: rooms, changed: changed);
}

/// Builds the single snapshot published after a startup verification pass.
/// Failed rooms become unknown, successful rooms use fresh server data, and
/// local tags/audience fallbacks continue to come from the latest user-owned
/// favourites list.
List<LiveRoom> buildVerifiedFavoriteSnapshot(
  Iterable<LiveRoom> currentRooms,
  Map<String, LiveRoom> successfulUpdates,
) {
  final current = List<LiveRoom>.from(currentRooms);
  return mergeAuthoritativeFavoriteRefresh(
    current,
    current.map(favoriteRoomIdentity),
    successfulUpdates,
  ).rooms;
}

/// Applies one authoritative refresh without carrying a stale live flag across
/// a failed request.
///
/// Only identities included in [requestedRoomKeys] are verified. A successful
/// response replaces server-owned fields, a failed response becomes
/// [LiveStatus.unknown], and favourites outside the requested platform/tag
/// remain untouched. This is important for manual per-platform refreshes: the
/// previous implementation either retained a stale "live" bit after a failure
/// or, when invalidating globally, could mark unrelated platforms unknown.
({List<LiveRoom> rooms, bool changed}) mergeAuthoritativeFavoriteRefresh(
  Iterable<LiveRoom> currentRooms,
  Iterable<String> requestedRoomKeys,
  Map<String, LiveRoom> successfulUpdates,
) {
  final requested = requestedRoomKeys.toSet();
  var changed = false;
  final rooms = currentRooms
      .map((previous) {
        final key = favoriteRoomIdentity(previous);
        if (!requested.contains(key)) return previous;

        changed = true;
        final updated = successfulUpdates[key];
        if (updated != null) {
          return updated
              .copyWith(tagIds: List<String>.from(previous.tagIds))
              .withAudienceFallbackFrom(previous);
        }
        return previous.copyWith(status: false, liveStatus: LiveStatus.unknown);
      })
      .toList(growable: false);
  return (rooms: rooms, changed: changed);
}
