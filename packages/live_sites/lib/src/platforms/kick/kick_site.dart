import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/kick/danmaku/kick_danmaku.dart';
import 'package:live_sites/src/platforms/kick/danmaku/kick_session.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_parser.dart';

/// The Kick adapter: one channel request per room (the answer carries the
/// stream and the signed IVS master), plus the Pusher chat WebSocket.
///
/// Not migrated yet: directory and search.
final class KickSite with SiteRoomGuard implements LiveSite, LiveDanmakuCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.kick;

  @override
  String get id => SiteIds.kick;

  @override
  SiteMetadata get metadata => const SiteMetadata(id: SiteIds.kick, displayName: 'Kick', homeUrl: 'https://kick.com');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('kick directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('kick directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('kick search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _channel(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    return const [LivePlayQuality(label: 'master')];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _channel(room.roomId) : room;
    return KickParser.playLines(fresh.data, room.roomId);
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _channel(room.roomId);
    return room.mergeFrom(fresh);
  }

  /// Opens the Pusher chat for [room].
  ///
  /// The chatroom and channel ids come from the channel answer and are
  /// re-read on every connect (not cached). There is no subscribing to a
  /// guessed chatroom, so a channel the answer gives no chatroom id for ends
  /// with a [SiteNotFoundError] rather than a socket on the wrong room.
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final data = (await _channel(room.roomId)).data;
    final channelId = data is Map<String, Object?> ? _asInt(data['channelId']) : null;
    final chatroomId = data is Map<String, Object?> ? _asInt(data['chatroomId']) : null;
    final args = KickDanmakuProtocol.checked(
      KickDanmakuArgs(chatroomId: chatroomId ?? 0, channelId: channelId ?? 0, slug: room.roomId),
    );
    if (args == null) {
      throw SiteNotFoundError('kick ${room.roomId}: no chatroom to subscribe to');
    }
    return await KickDanmakuSession.connect(args);
  }

  static int? _asInt(Object? value) => value is int ? value : int.tryParse('$value');

  Future<LiveRoom> _channel(String roomId) async {
    final slug = KickParser.normalizeSlug(roomId);
    if (slug == null) {
      throw SiteNotFoundError('kick: "${roomId.trim()}" is not a channel');
    }
    final response = await http.send(
      LiveRequest.get(KickParser.channelUrl(slug), headers: KickParser.headers, site: id),
    );
    return KickParser.room(response.text, requestedSlug: slug, status: response.statusCode);
  }
}
