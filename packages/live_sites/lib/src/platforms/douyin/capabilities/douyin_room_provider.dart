import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_endpoints.dart';
import 'package:live_sites/src/platforms/douyin/douyin_site.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_failure.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Douyin's rooms: detail by web_rid or by a broadcast's room_id, with the
/// recommendation feed as the default directory.
///
/// The room's identity is its lasting web_rid; this broadcast's room_id, the
/// stream description and the danmaku arguments ride in its
/// [RoomRuntime] handles.
final class DouyinRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  DouyinRoomProvider({required this.site});

  /// The site this capability serves.
  final DouyinSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await detail(roomId));
    } on DouyinFailure catch (failure) {
      return left(failure.toLiveSiteError('douyin'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'douyin', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final cookie = await site.cookie();
      final response = await site.httpGet(DouyinEndpoints.feed(), headers: site.apiHeaders(cookie));
      final rooms = DouyinRoomParser.feed(response.text, status: response.status, headers: response.headers);
      return right(LivePage(items: rooms, hasMore: rooms.isNotEmpty));
    } on DouyinFailure catch (failure) {
      return left(failure.toLiveSiteError('douyin'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'douyin', message: '$error', cause: error));
    }
  }

  /// The room at [roomId] (a web_rid, or a broadcast's room_id whose owner's
  /// web_rid then becomes the identity), with its stream and danmaku handles.
  Future<LiveRoom> detail(String roomId) async {
    final fetched = await site.fetch(roomId);
    final parse = fetched.room;
    final broadcast = parse.roomId;
    var room = parse.room;
    final startedAt = room.broadcast.isLiveNow && room.broadcast.startedAt == null
        ? await _startOf(broadcast, webRid: room.roomId)
        : null;
    if (startedAt != null) room = room.copyWith(broadcast: room.broadcast.copyWith(startedAt: startedAt));
    return room.copyWith(
      runtime: RoomRuntime(
        streamHandle: DouyinRoomData(
          webRid: room.roomId,
          roomId: broadcast,
          streamUrl: parse.streamUrl,
          issuedAt: fetched.issuedAt,
        ),
        danmakuHandle: DouyinDanmakuArgs(
          webRid: room.roomId,
          roomId: broadcast ?? '',
          userId: parse.userUniqueId ?? site.visitorId,
          cookie: fetched.cookie,
        ),
      ),
    );
  }

  /// The broadcast's start time, waited for at most
  /// [DouyinSite.startLookupWait]; a slow answer is not a failure (the room
  /// simply arrives without one).
  Future<DateTime?> _startOf(String? broadcast, {required String webRid}) async {
    if (broadcast == null || broadcast.isEmpty) return null;
    try {
      return await site.startTime(broadcast, webRid: webRid).timeout(DouyinSite.startLookupWait);
    } on TimeoutException {
      return null;
    } on DouyinFailure {
      return null;
    }
  }
}
