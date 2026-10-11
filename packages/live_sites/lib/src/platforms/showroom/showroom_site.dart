import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/showroom/danmaku/showroom_danmaku.dart';
import 'package:live_sites/src/platforms/showroom/danmaku/showroom_session.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_parser.dart';

/// The SHOWROOM adapter: profile + live_info + streaming_url flow and the
/// `live/onlives` directory.
///
/// The danmaku transport is the broadcast WebSocket (`bcsvr`), whose host
/// and per-broadcast key come from the same `live/live_info` answer the room
/// snapshot does.
///
/// Not migrated yet: search and the room's gift catalog (a gift is reported
/// by its id until the catalog lands).
final class ShowroomSite
    with SiteRoomGuard
    implements LiveSite, LiveDanmakuCapability, LiveAreaCatalog, LiveDirectoryCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  /// Room ids resolved from url keys.
  final Map<String, int> _keys = {};

  /// How long the live snapshot is reused after it arrived: the pages of one
  /// browse come from the same answer, so they neither repeat nor skip the
  /// rooms page 1 showed.
  static const Duration snapshotLifetime = Duration(seconds: 30);

  Map<String, Object?>? _snapshot;
  DateTime? _snapshotAt;

  @override
  String get siteId => SiteIds.showroom;

  @override
  String get id => SiteIds.showroom;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.showroom, displayName: 'SHOWROOM', homeUrl: 'https://www.showroom-live.com');

  /// Page [page] of the site's Popularity group: the rooms the site itself
  /// recommends.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) => _directory(null, page);

  /// Page [page] of one genre; a genre the snapshot no longer carries is not
  /// found rather than empty.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) => _directory(_genreId(area), page);

  /// One page of the snapshot: [genreId] null is every live once, otherwise
  /// that genre's rooms.
  Future<LivePage<LiveRoom>> _directory(int? genreId, int page) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    final lives = ShowroomParser.lives(await _liveSnapshot(fresh: page == 1), genreId: genreId);
    final start = (page - 1) * ShowroomParser.directoryPageSize;
    if (start >= lives.length) {
      return LivePage<LiveRoom>(items: const [], totalCount: lives.length);
    }
    final end = (start + ShowroomParser.directoryPageSize).clamp(start, lives.length);
    final hasMore = end < lives.length;
    return LivePage(
      items: lives.sublist(start, end),
      hasMore: hasMore,
      nextPage: hasMore ? page + 1 : null,
      totalCount: lives.length,
    );
  }

  /// The live snapshot: page 1 asks anew (a pull to refresh), a later page
  /// reuses the answer while it is younger than [snapshotLifetime]. Every
  /// genre is one request's answer, so paging costs one snapshot, not one
  /// request per page.
  Future<Map<String, Object?>> _liveSnapshot({required bool fresh}) async {
    final cached = _snapshot;
    final at = _snapshotAt;
    if (!fresh && cached != null && at != null && DateTime.now().difference(at) < snapshotLifetime) {
      return cached;
    }
    final response = await http.send(
      LiveRequest.get(
        Uri.https('www.showroom-live.com', '/api/live/onlives'),
        headers: ShowroomParser.headers,
        site: siteId,
      ),
    );
    final root = ShowroomParser.data(response.text, status: response.statusCode, what: 'live/onlives');
    _snapshot = root;
    _snapshotAt = DateTime.now();
    return root;
  }

  /// The genre number of [area]; an area that carries none is a caller
  /// error, refused before any request.
  static int _genreId(LiveArea area) {
    final genre = int.tryParse(area.id.trim());
    if (genre == null || genre < 0) {
      throw SiteError.invalidRoomId(area.id);
    }
    return genre;
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('showroom search lands with its migration');
  }

  /// The site's genres, which are the groups its live snapshot is divided
  /// into — there is no separate catalogue endpoint.
  @override
  Future<List<LiveArea>> getAreas() async {
    final response = await http.send(
      LiveRequest.get(
        Uri.https('www.showroom-live.com', '/api/live/onlives'),
        headers: ShowroomParser.headers,
        site: siteId,
      ),
    );
    return ShowroomParser.genres(ShowroomParser.data(response.text, status: response.statusCode, what: 'live/onlives'));
  }

  /// Opens a danmaku session for [room].
  ///
  /// The credentials are re-read from `live/live_info` on every connect
  /// rather than cached: the broadcast key belongs to one broadcast, so a
  /// reconnect after the streamer restarts needs the new one — and a room
  /// that is not on air has no key at all, which is why this answers with a
  /// [SiteNotFoundError] instead of opening a socket that would never
  /// subscribe to anything.
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final roomId = await _roomId(room.roomId);
    final args = await _danmakuArgs(roomId);
    if (args == null) {
      throw SiteNotFoundError('showroom ${room.roomId}: not on air, no danmaku key');
    }
    return await ShowroomDanmakuSession.connect(args);
  }

  /// The broadcast's danmaku credentials, or null when the room is not on
  /// air (the answer then carries no key) or the answer fails validation.
  Future<ShowroomDanmakuArgs?> _danmakuArgs(int roomId) async {
    final (_, info) = await _profileAndInfo(roomId);
    final host = info['bcsvr_host']?.toString() ?? '';
    final key = info['bcsvr_key']?.toString() ?? '';
    return ShowroomDanmakuProtocol.checked(ShowroomDanmakuArgs(roomId: roomId, host: host, key: key));
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final roomId = await _roomId(room.roomId);
    final (profile, info) = await _profileAndInfo(roomId);
    final fresh = ShowroomParser.room(profile, info, roomId: roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final lines = await _lines(room.roomId);
    final labels = <String>{
      for (final line in lines)
        if (line.lineId != null) line.lineId!,
    };
    return [for (final (index, label) in labels.indexed) LivePlayQuality(label: label, sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final lines = await _lines(room.roomId);
    final matching = lines.where((line) => line.lineId == quality.label).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final roomId = await _roomId(room.roomId);
    final (profile, info) = await _profileAndInfo(roomId);
    return room.mergeFrom(ShowroomParser.room(profile, info, roomId: roomId));
  }

  /// The numeric room id of [reference]: digits pass through, url keys are
  /// resolved once via `room/status` and remembered.
  Future<int> _roomId(String reference) async {
    final direct = ShowroomParser.roomNumber(reference);
    if (direct != null) {
      return direct;
    }
    if (!ShowroomParser.isUrlKey(reference)) {
      throw SiteNotFoundError('showroom: "${reference.trim()}" is not a room');
    }
    final cached = _keys[reference];
    if (cached != null) {
      return cached;
    }
    final response = await http.send(
      LiveRequest.get(
        Uri.https('www.showroom-live.com', '/api/room/status', {'room_url_key': reference}),
        headers: ShowroomParser.headers,
        site: id,
      ),
    );
    final roomId = ShowroomParser.roomIdOfStatus(response.text, status: response.statusCode);
    return _keys[reference] = roomId;
  }

  Future<(Map<String, Object?>, Map<String, Object?>)> _profileAndInfo(int roomId) async {
    final query = {'room_id': '$roomId'};
    final responses = await Future.wait([
      http.send(
        LiveRequest.get(
          Uri.https('www.showroom-live.com', '/api/room/profile', query),
          headers: ShowroomParser.headers,
          site: id,
        ),
      ),
      http.send(
        LiveRequest.get(
          Uri.https('www.showroom-live.com', '/api/live/live_info', query),
          headers: ShowroomParser.headers,
          site: id,
        ),
      ),
    ]);
    return (
      ShowroomParser.data(responses[0].text, status: responses[0].statusCode, what: 'room/profile'),
      ShowroomParser.data(responses[1].text, status: responses[1].statusCode, what: 'live_info'),
    );
  }

  Future<List<LivePlayLine>> _lines(String reference) async {
    final roomId = await _roomId(reference);
    final response = await http.send(
      LiveRequest.get(
        Uri.https('www.showroom-live.com', '/api/live/streaming_url', {'room_id': '$roomId', 'abr_available': '1'}),
        headers: ShowroomParser.headers,
        site: id,
      ),
    );
    return ShowroomParser.playLines(response.text, roomId: roomId, status: response.statusCode);
  }
}
