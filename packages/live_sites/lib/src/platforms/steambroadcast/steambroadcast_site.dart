import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_parser.dart';

/// The Steam Broadcast adapter: profile + getbroadcastmpd + info flow.
///
/// Not migrated yet: the directory, the custom-URL (vanity) resolution and
/// the chat.
final class SteamBroadcastSite with SiteRoomGuard implements LiveSite {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.steamBroadcast;

  @override
  String get id => SiteIds.steamBroadcast;

  @override
  SiteMetadata get metadata => const SiteMetadata(
    id: SiteIds.steamBroadcast,
    displayName: 'Steam Broadcast',
    homeUrl: 'https://steamcommunity.com/broadcast/',
  );

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('steambroadcast directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('steambroadcast directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('steambroadcast search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _read(room.roomId);
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
    final fresh = room.data == null ? await _read(room.roomId) : room;
    final lines = SteamBroadcastParser.playLines(fresh.data, room.roomId);
    if (lines.isEmpty) {
      throw SiteNotFoundError('steambroadcast ${room.roomId}: not broadcasting');
    }
    return lines;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _read(room.roomId);
    return room.mergeFrom(fresh);
  }

  /// The room: profile, getbroadcastmpd (state and master) and, unless
  /// offline, getbroadcastinfo (title, game, cover).
  Future<LiveRoom> _read(String roomId) async {
    final steamId = roomId.trim();
    if (!SteamBroadcastParser.isSteamId(steamId)) {
      throw SiteNotFoundError('steambroadcast: "$steamId" is not a Steam id');
    }
    final profileResponse = await http.send(
      LiveRequest.get(SteamBroadcastParser.profileUrl(steamId), headers: SteamBroadcastParser.headers, site: id),
    );
    final profile = SteamBroadcastParser.profile(
      profileResponse.text,
      steamId: steamId,
      status: profileResponse.statusCode,
    );
    final mpdResponse = await http.send(
      LiveRequest.get(SteamBroadcastParser.mpdUrl(steamId), headers: SteamBroadcastParser.headers, site: id),
    );
    final broadcast = SteamBroadcastParser.broadcast(mpdResponse.text, status: mpdResponse.statusCode);
    var title = broadcast.title;
    String? cover;
    var viewers = broadcast.viewers;
    if (broadcast.status == LiveStatus.live || broadcast.status == LiveStatus.replay) {
      try {
        final infoResponse = await http.send(
          LiveRequest.get(SteamBroadcastParser.infoUrl(steamId), headers: SteamBroadcastParser.headers, site: id),
        );
        final info = SteamBroadcastParser.info(infoResponse.text, steamId: steamId, status: infoResponse.statusCode);
        if (info.title.isNotEmpty) {
          title = info.title;
        }
        cover = info.cover;
        viewers = info.viewers ?? viewers;
      } on SiteError {
        // The title, game and cover stay those of getbroadcastmpd.
      }
    }
    return SteamBroadcastParser.room(
      steamId: steamId,
      status: broadcast.status,
      profile: profile,
      title: title,
      cover: cover,
      viewers: viewers,
      restriction: broadcast.restriction,
      master: broadcast.master,
    );
  }
}
