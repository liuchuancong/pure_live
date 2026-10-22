import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_endpoints.dart';
import 'package:live_sites/src/platforms/douyin/douyin_manifest.dart';
import 'package:live_sites/src/platforms/douyin/douyin_site.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_failure.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Douyin's discovery feed: the unsigned `webcast/feed/` recommendations.
///
/// The feed takes no page — every request is a new random draw — so a later
/// page only ever yields the rooms the earlier draws did not deliver, and a
/// draw that brings few new rooms is followed by another (at most
/// [maxDraws] per page, until the page holds [fillRooms]). An empty page ends
/// the list; a later draw that fails keeps what was already drawn.
final class DouyinDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  DouyinDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final DouyinSite site;

  /// Draws a later page makes at most.
  static const int maxDraws = 3;

  /// Rooms a later page fills before it stops drawing.
  static const int fillRooms = 15;

  /// Rooms delivered since the first page (the feed repeats otherwise).
  final Set<String> _delivered = {};

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      return right(await recommended(request));
    } on DouyinFailure catch (failure) {
      return left(failure.toLiveSiteError(douyinSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: douyinSiteId, message: '$error', cause: error));
    }
  }

  /// One page of the feed (see the class note on the draws).
  Future<LivePage<LiveRoom>> recommended(LivePageRequest request) async {
    final number = request.page < 1 ? 1 : request.page;
    if (number <= 1) {
      _delivered.clear();
      final rooms = await draw();
      return LivePage(items: rooms, hasMore: rooms.isNotEmpty);
    }
    final rooms = <LiveRoom>[];
    for (var draws = 0; draws < maxDraws && rooms.length < fillRooms; draws++) {
      final List<LiveRoom> fresh;
      try {
        fresh = await draw();
      } on DouyinFailure {
        if (rooms.isEmpty) rethrow;
        break;
      }
      if (fresh.isEmpty) break;
      rooms.addAll(fresh);
    }
    return LivePage(items: rooms, hasMore: rooms.isNotEmpty);
  }

  /// One feed request's rooms, minus what was delivered since page 1.
  Future<List<LiveRoom>> draw() async {
    final cookie = await site.cookie();
    final response = await site.httpGet(DouyinEndpoints.feed(), headers: site.apiHeaders(cookie));
    final rooms = DouyinRoomParser.feed(response.text, status: response.status, headers: response.headers);
    return [
      for (final room in rooms)
        if (_delivered.add(room.roomId)) room,
    ];
  }
}
