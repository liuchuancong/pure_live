import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_parser.dart';

/// The NetEase CC adapter: the two-step guest flow (anchor lives →
/// channel) plus the h5 `video_play_url` tiers.
///
/// Not migrated yet: the room page's `__NEXT_DATA__` entry for anchors
/// without a live channel, the paid-show ticket flow and the danmaku
/// capability (CC had none in 3.x either).
final class CcSite
    with SiteRoomGuard
    implements LiveSite, LiveDirectoryCapability, LiveSearchCapability, LiveAnchorSearch {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.cc;

  @override
  String get id => SiteIds.cc;

  @override
  SiteMetadata get metadata => const SiteMetadata(id: SiteIds.cc, displayName: '网易CC直播', homeUrl: 'https://cc.163.com');

  /// Every live room, by the site's heat order.
  ///
  /// The endpoint pages by offset (`start`/`size`), which the page API
  /// converts; 100 rooms a page is what the site's own popular page asks
  /// for.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    final number = page < 1 ? 1 : page;
    final data = await _json('/api/category/live/', {
      'format': 'json',
      'start': '${(number - 1) * _pageSize}',
      'size': '$_pageSize',
    });
    return CcParser.roomList(data);
  }

  /// The rooms of one game area.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    final game = area.id.trim();
    if (game.isEmpty) {
      throw SiteError.invalidRoomId(area.id);
    }
    final number = page < 1 ? 1 : page;
    // The trailing slash matters: without it the site answers a 301 the
    // transport does not follow for JSON requests.
    final data = await _json('/api/category/$game/', {
      'format': 'json',
      'tag_id': '0',
      'start': '${(number - 1) * _pageSize}',
      'size': '$_pageSize',
    });
    return CcParser.roomList(data, gametype: game);
  }

  /// Streamers matching a keyword, live or not.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    final text = keyword.trim();
    if (text.isEmpty) {
      return const LivePage<LiveRoom>(items: []);
    }
    final data = await _json('/search/anchor/', {
      'query': text,
      // The search endpoint caps its page at 50 rows; asking for the
      // listing's 100 gets an error envelope instead of results.
      'size': '$_searchPageSize',
      'page': '${page < 1 ? 1 : page}',
    }, trailingSlash: true);
    return CcParser.searchRooms(data);
  }

  /// The streamers matching [keyword], live or not.
  ///
  /// The same endpoint as the room search, read as people: the site answers
  /// one list of streamers and the two searches differ only in how the rows
  /// are interpreted — a person, or the room that person is in.
  @override
  Future<LivePage<LiveAnchor>> searchAnchors(String keyword, {int page = 1}) async {
    final text = keyword.trim();
    if (text.isEmpty) {
      return const LivePage<LiveAnchor>(items: []);
    }
    final data = await _json('/search/anchor/', {
      'query': text,
      'size': '$_searchPageSize',
      'page': '${page < 1 ? 1 : page}',
    });
    return CcParser.searchAnchors(data);
  }

  /// One JSON request, with the site's own error conventions.
  Future<Map<String, Object?>> _json(String path, Map<String, String> query, {bool trailingSlash = false}) async {
    final response = await http.send(
      LiveRequest.get(Uri.https('cc.163.com', path, query), headers: CcParser.apiHeaders, site: siteId),
    );
    return CcParser.decode(response.text, status: response.statusCode, what: trailingSlash ? path : 'cc');
  }

  /// How many rooms one listing page asks for (the endpoint's maximum).
  static const int _pageSize = 100;

  /// How many rows one search page asks for (a lower cap than the listings).
  static const int _searchPageSize = 50;

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _freshRoom(room);
    // An anchor with no live channel: keep the stored fields, mark
    // offline.
    return room.mergeFrom(fresh ?? room.copyWith(status: LiveStatus.offline));
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final data = await _playData(room.roomId, vbrname: null, cdn: '');
    return CcParser.qualities(data);
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final channel = switch (room.data) {
      final String value when value.isNotEmpty => value,
      _ => '',
    };
    final data = await _playData(room.roomId, vbrname: quality.label, cdn: channel);
    return CcParser.playLines(data, room.roomId, cdn: channel);
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _freshRoom(room);
    if (fresh != null) {
      return room.mergeFrom(fresh);
    }
    return room.copyWith(status: LiveStatus.offline);
  }

  /// The fresh room from the lives → channel flow, or null when the
  /// anchor exists but is not broadcasting.
  Future<LiveRoom?> _freshRoom(LiveRoom room) async {
    final ccid = room.roomId.trim();
    final lives = await http.send(
      LiveRequest.get(
        Uri.https('api.cc.163.com', '/v1/activitylives/anchor/lives', {'anchor_ccid': ccid}),
        headers: CcParser.mediaHeaders(ccid),
        site: id,
      ),
    );
    final channel = CcParser.liveChannel(lives.text, ccid: ccid, status: lives.statusCode);
    if (channel == null) {
      return null;
    }
    final response = await http.send(
      LiveRequest.get(
        Uri.https('cc.163.com', '/live/channel/', {'channelids': channel}),
        headers: CcParser.mediaHeaders(ccid),
        site: id,
      ),
    );
    return CcParser.channelRoom(response.text, ccid: ccid, status: response.statusCode);
  }

  Future<Map<String, Object?>> _playData(String ccid, {required String? vbrname, required String cdn}) async {
    final response = await http.send(
      LiveRequest.get(
        Uri.https('vapi.cc.163.com', '/video_play_url/$ccid', {
          'src': 'webcc_h5',
          'vbrmode': '1',
          'use_new_vbrmap': '1',
          'secure': '1',
          'vbrname': ?vbrname,
          if (cdn.isNotEmpty) 'cdn': cdn,
        }),
        headers: CcParser.mediaHeaders(ccid),
        site: id,
      ),
    );
    return CcParser.playData(response.text, status: response.statusCode);
  }
}
