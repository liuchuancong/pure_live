import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_parser.dart';

/// The LiveMe adapter: short-id mapping → signed queryinfosimple flow.
///
/// Not migrated yet: the guest profile fetch (bio), directory, search and
/// the danmaku transport.
final class LiveMeSite with SiteRoomGuard implements LiveSite {
  /// A site over [http]; [signer] is injectable for tests.
  new({required this.http, LiveMeSigner? signer}) : signer = signer ?? LiveMeSigner();

  /// The HTTP transport.
  final LiveHttp http;

  /// The request signer.
  final LiveMeSigner signer;

  @override
  String get siteId => SiteIds.liveme;

  @override
  String get id => SiteIds.liveme;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.liveme, displayName: 'LiveMe', homeUrl: 'https://www.liveme.com');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    throw UnimplementedError('liveme directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    throw UnimplementedError('liveme directory lands with its migration');
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('liveme search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _room(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _room(room.roomId);
    final lines = LiveMeParser.playLines(fresh.data, room.roomId);
    final labels = <String>{
      for (final line in lines)
        if (line.lineId != null) line.lineId!,
    };
    return [for (final (index, label) in labels.indexed) LivePlayQuality(label: label, sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = await _room(room.roomId);
    final lines = LiveMeParser.playLines(fresh.data, room.roomId);
    final matching = lines.where((line) => line.lineId == quality.label).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _room(room.roomId);
    return room.mergeFrom(fresh);
  }

  /// The room for a short id: mapping → signed queryinfosimple.
  Future<LiveRoom> _room(String shortId) async {
    final now = DateTime.now();
    final mappingResponse = await http.send(
      LiveRequest.get(
        Uri.https(LiveMeParser.apiHost, '/liveme_ent/v1/user/uid_vid_by_short_id', {
          ...LiveMeParser.guestQuery(now),
          'short_id': shortId,
        }),
        headers: LiveMeParser.headers(shortId: shortId),
        site: id,
      ),
    );
    final mapping = LiveMeParser.mapping(mappingResponse.text, status: mappingResponse.statusCode);
    if (mapping.videoId.isEmpty) {
      return LiveRoom(platform: SiteIds.liveme, roomId: shortId, status: LiveStatus.offline);
    }

    final signed = signer.sign(
      query: _videoQuery,
      form: {
        '_time': '${now.millisecondsSinceEpoch}',
        'thirdchannel': '6',
        'videoid': mapping.videoId,
        'area': 'en',
        'vali': signer.vali(),
      },
      now: now,
    );
    final response = await http.send(
      LiveRequest.form(
        Uri.https(LiveMeParser.apiHost, '/live/queryinfosimple', _videoQuery),
        fields: signed.fields,
        headers: {
          ...LiveMeParser.headers(shortId: shortId),
          'lm-s-sign': signed.signature,
        },
        site: id,
      ),
    );
    return LiveMeParser.room(response.text, shortId: shortId, status: response.statusCode);
  }

  static const Map<String, String> _videoQuery = {'alias': 'liveme', 'tongdun_black_box': '1', 'os': 'web'};
}
