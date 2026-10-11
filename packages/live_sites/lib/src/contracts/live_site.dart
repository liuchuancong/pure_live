import 'package:live_sites/src/contracts/site_error.dart';
import 'package:live_sites/src/models/live_area.dart';
import 'package:live_sites/src/models/live_play_line.dart';
import 'package:live_sites/src/models/live_room.dart';
import 'package:live_sites/src/registry/site_metadata.dart';

/// The main site contract. Room-level operations take the [LiveRoom] —
/// the room already carries platform, roomId and the adapter's runtime
/// context, so callers stop threading `platform`/`roomId` pairs around.
///
/// Non-room operations keep dedicated inputs: directory browsing and
/// search take queries (no room exists yet), and jump targets that are
/// not room ids (replay ids) travel as explicit parameters. Never accept
/// a hollow `LiveRoom` just to unify shapes.
abstract interface class LiveSite {
  /// The stable site id; equals [SiteMetadata.id] of [metadata].
  String get id;

  /// Display metadata, including the logo the UI should use.
  SiteMetadata get metadata;

  /// Recommended rooms, page-based starting at 1.
  Future<LivePage<LiveRoom>> getRecommendRooms({int page});

  /// Rooms of [area], page-based starting at 1.
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page});

  /// Room search; anchors search, when supported, is a capability.
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page});

  /// Loads or refreshes the full detail of [room], returning the merged
  /// room (identity preserved, sparse fields never erased).
  Future<LiveRoom> getRoomDetail(LiveRoom room);

  /// The quality levels [room] currently offers.
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room);

  /// Resolves playable lines of [room] at [quality]. Returns
  /// self-describing lines — URL, headers, lease — ready for a player.
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality);

  /// Lightweight status refresh for watched-room lists: feed the stored
  /// room in, get the fresh room out (same identity, updated status,
  /// audience and title).
  Future<LiveRoom> refreshLiveStatus(LiveRoom room);
}

/// A room guard shared by every adapter: validates that `room` belongs
/// to this site and carries a usable room id.
///
/// Adapters call it first in every room-level operation — one line, no
/// per-site repetition, and a wrong-platform room fails with
/// [SitePlatformMismatchError] instead of producing an unhelpful network
/// error.
mixin SiteRoomGuard {
  /// The site id this guard validates against.
  String get siteId;

  /// Validates [room] for this site; throws [SiteError] on mismatch.
  void guardRoom(LiveRoom room) {
    if (room.platform != siteId) {
      throw SiteError.platformMismatch(expected: siteId, actual: room.platform);
    }
    if (room.roomId.isEmpty) {
      throw SiteError.invalidRoomId(room.roomId);
    }
  }
}
