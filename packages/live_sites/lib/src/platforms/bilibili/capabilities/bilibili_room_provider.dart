import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_manifest.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_discovery_provider.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bilibili's rooms: the WBI-signed detail by any id the user knows (a short
/// id stays the card's identity), and the ranked list as the directory.
///
/// The canonical long id every stream and super-chat request needs rides in the
/// room's [RoomRuntime] handle. Its danmaku credentials do not: Bilibili mints
/// them with a second signed request, and the chat session asks for a fresh one
/// for itself, so reading them here would only hold up the room's own answer.
final class BilibiliRoomProvider implements LiveRoomProvider {
  /// Serves [site]; [discovery] answers the directory page (the same ranked
  /// list the discovery feed shows).
  BilibiliRoomProvider({required this.site, required this.discovery});

  /// The site this capability serves.
  final BilibiliSite site;

  /// The capability whose feed stands in for a room directory.
  final BilibiliDiscoveryProvider discovery;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await detail(roomId));
    } on BilibiliFailure catch (failure) {
      return left(failure.toLiveSiteError(bilibiliSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bilibiliSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      return right(await discovery.page(request));
    } on BilibiliFailure catch (failure) {
      return left(failure.toLiveSiteError(bilibiliSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bilibiliSiteId, message: '$error', cause: error));
    }
  }

  /// The room at [roomId] (its identity stays the id as asked for), with its
  /// long id in the runtime handle.
  Future<LiveRoom> detail(String roomId) async {
    final read = await _read(roomId);
    return read.room.rebuild(
      (b) => b..runtime = RoomRuntime.of(streamHandle: BilibiliRoomData(read.longId)).toBuilder(),
    );
  }

  /// The room at [roomId] as a refresh read: display state and figures from
  /// the WBI-signed metadata request, with no danmaku handshake.
  Future<LiveRoom> refresh(String roomId) async => (await _read(roomId)).room;

  /// The signed metadata read every entry point shares; the long id is
  /// remembered for the play and danmaku requests that need it.
  Future<({LiveRoom room, String longId})> _read(String roomId) async {
    final id = roomId.trim();
    if (BilibiliSite.roomNumber(id) == null) {
      throw BilibiliFailure(BilibiliFailureKind.notFound, 'room id $id is not a number');
    }
    final result = await site.signed(BilibiliEndpoints.roomDetailPath, {
      'room_id': id,
    }, (response) => BilibiliRoomParser.roomDetail(response.text, requestedId: id, status: response.status));
    final longId = result.value.longId;
    site.rememberLongId(id, longId);
    return (room: result.value.room, longId: longId);
  }

  /// The super chats of [roomId] (`av/v1/SuperChat/getMessageList`, asked with
  /// the room's canonical long id); the read path behind the site's super chat
  /// feed capability.
  Future<List<LiveSuperChatMessage>> superChats(String roomId) async {
    final response = await site.unsignedGet(BilibiliEndpoints.superChats(site.longId(roomId)));
    return BilibiliRoomParser.superChats(response.text, status: response.status);
  }

  /// Whether the room is live right now (a carousel is not).
  Future<bool> liveStatus(String roomId) async {
    final response = await site.unsignedGet(BilibiliEndpoints.liveStatus(roomId.trim()));
    return BilibiliRoomParser.liveStatus(response.text, status: response.status);
  }
}
