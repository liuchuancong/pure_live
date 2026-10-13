import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/huya/api/huya_endpoints.dart';
import 'package:live_sites/src/platforms/huya/huya_site.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Huya's room feature: detail by numeric rid, plus the recommendation list
/// as the default directory. `profileRoom` refuses letter aliases, so a
/// non-numeric id is not-found without a request (a link resolves to a number
/// first through `HuyaLinkResolver`).
final class HuyaRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  HuyaRoomProvider({required this.site});

  /// The site this capability serves.
  final HuyaSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await detail(roomId));
    } on HuyaFailure catch (failure) {
      return left(failure.toLiveSiteError('huya'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'huya', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = request.page < 1 ? 1 : request.page;
      final response = await site.httpGet(
        HuyaEndpoints.liveList(page),
        headers: {...site.webHeaders(), 'origin': HuyaEndpoints.origin, 'referer': '${HuyaEndpoints.origin}/'},
      );
      final result = HuyaRoomParser.roomList(response.text, page: page, status: response.status);
      return right(LivePage(items: result.rooms, hasMore: result.hasMore));
    } on HuyaFailure catch (failure) {
      return left(failure.toLiveSiteError('huya'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'huya', message: '$error', cause: error));
    }
  }

  /// The room at [roomId] (a numeric rid), which stays its identity. The
  /// canonical rid rides along in the room's stream handle; a live room's
  /// danmaku handle carries the streamer uid and channel ids.
  Future<LiveRoom> detail(String roomId) async {
    final profile = await site.detailRoom(roomId);
    final rid = profile.room.roomId;
    final live = profile.room.broadcast.isLiveNow;
    return profile.room.copyWith(
      runtime: RoomRuntime(
        streamHandle: HuyaRoomData(rid),
        danmakuHandle: live
            ? HuyaDanmakuArgs(uid: profile.presenterUid, topSid: profile.topSid, subSid: profile.subSid)
            : null,
      ),
    );
  }
}
