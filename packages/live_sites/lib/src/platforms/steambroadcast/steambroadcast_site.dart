import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/steambroadcast/danmaku/steambroadcast_danmaku.dart';
import 'package:live_sites/src/platforms/steambroadcast/danmaku/steambroadcast_session.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_parser.dart';

/// The Steam Broadcast adapter: profile + getbroadcastmpd + info flow.
///
/// Not migrated yet: the directory's full set and the custom-URL (vanity)
/// resolution. The chat ([connect]) polls the broadcast's chat log over HTTP.
final class SteamBroadcastSite
    with SiteRoomGuard
    implements LiveSite, LiveAreaCatalog, LiveDirectoryCapability, LiveDanmakuCapability {
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

  /// The catalogue: one constant area, the trending broadcasts.
  @override
  Future<List<LiveArea>> getAreas() async => SteamBroadcastParser.areas();

  /// Page [page] of the trending broadcasts, which is what the site
  /// recommends.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    final response = await http.send(
      LiveRequest.get(SteamBroadcastParser.directoryUrl(page), headers: SteamBroadcastParser.headers, site: siteId),
    );
    return SteamBroadcastParser.directory(response.text, page: page, status: response.statusCode);
  }

  /// As [getRecommendRooms]; the site has one area and anything else is a
  /// caller error rather than a request that cannot work.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    if (!SteamBroadcastParser.isArea(area)) {
      throw SiteError.invalidRoomId(area.id);
    }
    return getRecommendRooms(page: page);
  }

  /// 3.x's search (Steam has no anonymous broadcast search): a Steam id or a
  /// watch/profile link is that account's room (the refresh, page 1 only; an
  /// account without a page is no result), and any other keyword filters
  /// directory page [page] by id, broadcaster, title and game (case ignored).
  /// A blank keyword or a page below one is nothing. A custom profile address
  /// is not resolved — that needs the profile XML.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    final raw = keyword.trim();
    if (raw.isEmpty) {
      return const LivePage<LiveRoom>(items: []);
    }
    final steamId = SteamBroadcastParser.steamIdOf(raw);
    if (steamId != null) {
      if (page != 1) {
        return const LivePage<LiveRoom>(items: []);
      }
      try {
        return LivePage<LiveRoom>(items: [await _read(steamId)]);
      } on SiteNotFoundError {
        return const LivePage<LiveRoom>(items: []);
      }
    }
    final directory = await getRecommendRooms(page: page);
    return LivePage<LiveRoom>(items: SteamBroadcastParser.filter(directory.items, raw.toLowerCase()));
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

  /// Opens Steam's broadcast chat: the session follows the broadcaster's
  /// current broadcast (looking up its `broadcastid` and chat log itself, so
  /// a fresh room id is enough here). A room id that is not a Steam 64-bit id
  /// ends with a [SiteNotFoundError].
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    return await SteamBroadcastDanmakuSession.connect(SteamBroadcastDanmakuArgs(steamId: room.roomId.trim()), http);
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
