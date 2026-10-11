import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_parser.dart';

/// The Twitch adapter: anonymous GraphQL + usher flow.
///
/// Not migrated yet: the directory (the web client has no persisted query
/// for it), search, the session cookie and the IRC chat.
final class TwitchSite with SiteRoomGuard implements LiveSite {
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

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('twitch search lands with its migration');
  }

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
