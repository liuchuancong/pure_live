import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/twitch/danmaku/twitch_session.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_parser.dart';

/// The Twitch adapter: anonymous GraphQL + usher flow, plus the IRC chat over
/// an anonymous WebSocket.
///
/// Not migrated yet: the directory and the session cookie.
final class TwitchSite with SiteRoomGuard implements LiveSite, LiveDanmakuCapability {
  /// A site over [http].
  new({required this.http}) : _deviceId = TwitchParser.deviceId();

  /// The HTTP transport.
  final LiveHttp http;

  final String _deviceId;

  /// The last access token per channel, reused for the play path.
  final Map<String, ({String value, String signature})> _tokens = {};

  @override
  String get siteId => SiteIds.twitch;

  @override
  String get id => SiteIds.twitch;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.twitch, displayName: 'Twitch', homeUrl: 'https://www.twitch.tv');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('twitch directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('twitch directory lands with its migration');
  }

  /// Channels matching [keyword], live or offline: the `SearchResultsPage_`
  /// `SearchResults` query, one page of thirty; a later page continues the
  /// cursor the previous page reported (so it must have been asked), and a
  /// blank keyword gives nothing without a request.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    final text = keyword.trim();
    if (text.isEmpty) {
      return const LivePage<LiveRoom>(items: []);
    }
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    final key = 'search|$text';
    final cursor = page == 1 ? null : _cursors['$key|$page'];
    if (page > 1 && cursor == null) {
      return const LivePage<LiveRoom>(items: []);
    }
    final response = await http.send(
      LiveRequest.custom(
        url: TwitchParser.gqlUrl,
        method: 'POST',
        body: jsonEncode(TwitchParser.searchOperation(text, cursor: cursor)),
        headers: TwitchParser.gqlHeaders(deviceId: _deviceId),
        site: id,
      ),
    );
    final result = TwitchParser.searchPage(response.text, status: response.statusCode);
    if (result.cursor != null) {
      _cursors['$key|${page + 1}'] = result.cursor!;
    }
    final hasMore = result.cursor != null && result.rooms.isNotEmpty;
    return LivePage<LiveRoom>(items: result.rooms, hasMore: hasMore, nextPage: hasMore ? page + 1 : null);
  }

  /// The cursor of each search page after the first, by `search|keyword|page`.
  final Map<String, String> _cursors = {};

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _user(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    // Usher answers one master playlist for every quality; the line is the
    // master and the player picks the variant.
    return const [LivePlayQuality(label: 'source')];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final login = room.roomId.toLowerCase();
    final token = _tokens[login] ?? await _accessToken(login);
    return [
      LivePlayLine(
        url: TwitchParser.usherUrl(login, token: token).toString(),
        headers: TwitchParser.mediaHeaders(login),
        format: StreamFormat.hls,
        codec: 'avc',
        lineId: 'source',
      ),
    ];
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _user(room.roomId);
    return room.mergeFrom(fresh);
  }

  /// Opens the IRC chat for [room] as an anonymous guest (this tree stores no
  /// Twitch login, so the join always uses an anonymous nick).
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    return await TwitchDanmakuSession.connect(room.roomId);
  }

  Future<LiveRoom> _user(String login) async {
    final normalized = login.toLowerCase();
    final response = await http.send(
      LiveRequest.custom(
        url: TwitchParser.gqlUrl,
        method: 'POST',
        body: jsonEncode(TwitchParser.userOperation(normalized)),
        headers: TwitchParser.gqlHeaders(deviceId: _deviceId),
        site: id,
      ),
    );
    return TwitchParser.room(response.text, login: normalized, status: response.statusCode);
  }

  Future<({String value, String signature})> _accessToken(String login) async {
    final response = await http.send(
      LiveRequest.custom(
        url: TwitchParser.gqlUrl,
        method: 'POST',
        body: jsonEncode(TwitchParser.accessTokenOperation(login)),
        headers: TwitchParser.gqlHeaders(deviceId: _deviceId),
        site: id,
      ),
    );
    final token = TwitchParser.accessToken(response.text, status: response.statusCode);
    return _tokens[login] = token;
  }
}
