import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_parser.dart';

/// The Look (网易 LOOK) adapter: the weapi room flow with the NetEase
/// request envelope (double AES-128-CBC + encSecKey).
///
/// Not migrated yet: search and the danmaku transport (the chat servers
/// come from a separate address endpoint).
final class LookLiveSite with SiteRoomGuard implements LiveSite, LiveAreaCatalog, LiveDirectoryCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.looklive;

  @override
  String get id => SiteIds.looklive;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.looklive, displayName: 'LOOK直播', homeUrl: 'https://look.163.com');

  /// The catalogue: the site's two feeds, and it is constant — the areas are
  /// the feeds themselves.
  @override
  Future<List<LiveArea>> getAreas() async => LookLiveParser.areas();

  /// Page [page] of both feeds merged, the video rooms first and each room
  /// once, which is what the site recommends.
  ///
  /// A feed that answered "no more" on an earlier page is not asked again,
  /// because the video feed is short and would answer empty on every later
  /// page; page 1 asks both and starts the record over, so pulling to refresh
  /// sees a feed that has grown again.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    if (page == 1) {
      _ended.clear();
    }
    final asked = [
      for (final kind in LookLiveKind.values)
        if (_stillOpen(kind, page)) kind,
    ];
    final pages = await Future.wait([for (final kind in asked) _list(kind, page)]);
    for (final (index, answered) in pages.indexed) {
      if (!answered.hasMore) {
        _ended[asked[index]] = page;
      }
    }
    final rooms = <String, LiveRoom>{};
    for (final answered in pages) {
      for (final room in answered.items) {
        rooms.putIfAbsent(room.roomId, () => room);
      }
    }
    return LivePage<LiveRoom>(
      items: rooms.values.toList(),
      hasMore: pages.any((answered) => answered.hasMore),
      nextPage: pages.any((answered) => answered.hasMore) ? page + 1 : null,
    );
  }

  /// Page [page] of one feed; an area that is not one of the two feeds is a
  /// caller error, refused before any request.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    final kind = LookLiveParser.kindOf(area.id);
    if (kind == null) {
      throw SiteError.invalidRoomId(area.id);
    }
    if (page < 1 || page > LookLiveParser.maxPage) {
      throw RangeError.range(page, 1, LookLiveParser.maxPage, 'page');
    }
    return _list(kind, page);
  }

  /// One page of one feed.
  Future<LivePage<LiveRoom>> _list(LookLiveKind kind, int page) async {
    if (page > LookLiveParser.maxPage) {
      throw RangeError.range(page, 1, LookLiveParser.maxPage, 'page');
    }
    final body = await LookLiveParser.formBody(LookLiveParser.listPayload(page));
    final response = await http.send(
      LiveRequest.custom(
        url: Uri.parse('${LookLiveParser.apiOrigin}${LookLiveParser.listPath(kind)}'),
        method: 'POST',
        headers: LookLiveParser.requestHeaders,
        body: body,
        site: id,
      ),
    );
    return LookLiveParser.directory(response.text, kind: kind, page: page, status: response.statusCode);
  }

  /// Whether a feed is worth asking for [page]: one that answered "no more"
  /// on an earlier page is not.
  bool _stillOpen(LookLiveKind kind, int page) {
    final ended = _ended[kind];
    return ended == null || page <= ended;
  }

  /// The last page each feed answered "no more" on, which keeps a short feed
  /// out of the merged listing's later pages.
  final Map<LookLiveKind, int> _ended = {};

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('looklive search lands with its migration');
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
    final fresh = room.data == null ? await _room(room.roomId) : room;
    final lines = LookLiveParser.playLines(_liveUrlOf(fresh.data), room.roomId);
    final labels = <String>{
      for (final line in lines)
        if (line.lineId != null) line.lineId!,
    };
    return [
      for (final (index, label) in labels.indexed) LivePlayQuality(label: label == 'hls' ? 'HLS' : 'FLV', sort: -index),
    ];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final fresh = room.data == null ? await _room(room.roomId) : room;
    final lines = LookLiveParser.playLines(_liveUrlOf(fresh.data), room.roomId);
    final wantHls = quality.label == 'HLS';
    final matching = lines.where((line) => (line.format == StreamFormat.hls) == wantHls).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _room(room.roomId);
    return room.mergeFrom(fresh);
  }

  /// The liveUrl of a room whose data is the roomInfo map.
  static Object? _liveUrlOf(Object? data) => data is Map<String, Object?> ? data['liveUrl'] : null;

  Future<LiveRoom> _room(String roomId) async {
    final body = await LookLiveParser.formBody({'liveRoomNo': roomId});
    final response = await http.send(
      LiveRequest.custom(
        url: Uri.parse('${LookLiveParser.apiOrigin}${LookLiveParser.roomPath}'),
        method: 'POST',
        headers: LookLiveParser.requestHeaders,
        body: body,
        site: id,
      ),
    );
    return LookLiveParser.room(response.text, roomId: roomId, status: response.statusCode);
  }
}
