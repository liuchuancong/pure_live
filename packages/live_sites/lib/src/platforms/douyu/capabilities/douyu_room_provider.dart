import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/douyu/api/douyu_endpoints.dart';
import 'package:live_sites/src/platforms/douyu/douyu_manifest.dart';
import 'package:live_sites/src/platforms/douyu/douyu_site.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_failure.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Douyu's room feature: detail by rid/靓号/alias, plus the recommendation
/// list as the default directory.
/// Douyu's room feature: detail by rid/靓号/alias, plus the recommendation list as the default directory.
/// Douyu's room feature: detail by rid, 靓号 or alias, plus the recommendation list as the default directory.
final class DouyuRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  /// Serves [site].
  DouyuRoomProvider({required this.site});

  /// The site this capability serves.
  final DouyuSite site;

  @override
  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await detail(roomId));
    } on DouyuFailure catch (failure) {
      return left(failure.toLiveSiteError(douyuSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: douyuSiteId, message: '$error', cause: error));
    }
  }

  @override
  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = request.page < 1 ? 1 : request.page;
      final response = await site.httpGet(DouyuEndpoints.recommend(page), headers: site.apiHeaders(''));
      final result = DouyuRoomParser.roomList(response.text, page: page, status: response.status);
      return right(LivePage(items: result.rooms, hasMore: result.hasMore));
    } on DouyuFailure catch (failure) {
      return left(failure.toLiveSiteError(douyuSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: douyuSiteId, message: '$error', cause: error));
    }
  }

  /// The room at [roomId] (a rid, a 靓号 or an alias), which stays its
  /// identity. The canonical rid rides along in the room's stream handle,
  /// the gift catalogue in its danmaku handle.
  Future<LiveRoom> detail(String roomId) async {
    final id = roomId.trim();
    if (!DouyuRoomParser.isRoomKey(id)) {
      throw DouyuFailure(DouyuFailureKind.notFound, 'room id "$id" is not a room address');
    }
    await site.renewLogin();
    final rid = await site.ridFor(id);
    if (rid == null) {
      throw DouyuFailure(DouyuFailureKind.notFound, 'alias $id does not lead to a room');
    }
    final response = await site.httpGet(
      DouyuEndpoints.roomDetail(rid),
      headers: {'referer': 'https://www.douyu.com/$rid', 'user-agent': DouyuEndpoints.detailUserAgent},
    );
    final result = DouyuRoomParser.roomDetail(response.text, requestedId: id, status: response.status);
    site.rememberRid(id, result.rid);
    return result.room.rebuild(
      (b) => b
        ..runtime = RoomRuntime.of(
          streamHandle: DouyuRoomData(result.rid),
          danmakuHandle: DouyuDanmakuArgs(result.rid, result.gifts),
        ).toBuilder(),
    );
  }
}
