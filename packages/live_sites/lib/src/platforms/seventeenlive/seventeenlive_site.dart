import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_parser.dart';

/// The 17LIVE (イチナナ) adapter: an anonymous room, its pull streams and the
/// website's recommendation sections. No cookie and no signature.
///
/// A room is the broadcaster's fixed `liveStreamID`; the directory is the
/// region's recommendation sections (page N replays the cursor from page 1);
/// search is one room answer for an id or link, else one keyword search; a
/// follow refresh, the live state, room entry and playback are one `lives/<id>`
/// each. Playback qualities ride in the room answer's [LiveRoom.data].
///
/// Not migrated yet: the danmaku (17LIVE's chat is an Ably channel named by the
/// room id; see the next slice).
final class SeventeenLiveSite
    with SiteRoomGuard
    implements LiveSite, LiveAreaCatalog, LiveDirectoryCapability, LiveSearchCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  static const String _api = SeventeenLiveParser.apiHost;

  @override
  String get siteId => SiteIds.seventeenLive;

  @override
  String get id => SiteIds.seventeenLive;

  @override
  SiteMetadata get metadata => const SiteMetadata(
    id: SiteIds.seventeenLive,
    displayName: SeventeenLiveParser.displayName,
    homeUrl: SeventeenLiveParser.origin,
  );

  /// The catalogue: the three regions, without a request.
  @override
  Future<List<LiveArea>> getAreas() async => SeventeenLiveParser.areas();

  /// Page [page] of the recommendations (Japan).
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) => _directory(page, null);

  /// Page [page] of one region.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    SeventeenLiveParser.regionOf(area);
    return _directory(page, area);
  }

  /// Page [page] (1–[SeventeenLiveParser.maxPage]) of [area]'s region, replayed
  /// from page 1 by cursor (the sections endpoint pages by an opaque cursor, so
  /// a page number costs one request per page before it).
  Future<LivePage<LiveRoom>> _directory(int page, LiveArea? area) async {
    final number = page < 1 ? 1 : (page > SeventeenLiveParser.maxPage ? SeventeenLiveParser.maxPage : page);
    final region = SeventeenLiveParser.regionOf(area);
    String? cursor;
    var rooms = const <LiveRoom>[];
    var hasMore = false;
    for (var current = 1; current <= number; current++) {
      final result = await _sectionPage(cursor, region);
      rooms = result.rooms;
      cursor = result.nextCursor;
      hasMore = cursor != null;
      if (cursor == null) {
        return LivePage<LiveRoom>(items: current == 1 ? rooms : const []);
      }
    }
    return LivePage<LiveRoom>(items: rooms, hasMore: hasMore, nextPage: hasMore ? number + 1 : null);
  }

  /// One sections request after [cursor].
  Future<({List<LiveRoom> rooms, String? nextCursor})> _sectionPage(String? cursor, String region) async {
    final response = await http.send(
      LiveRequest.get(
        Uri.https(_api, '/api/v1/sections', SeventeenLiveParser.sectionsQuery(cursor, regionCode: region)),
        headers: SeventeenLiveParser.catalogHeaders,
        site: siteId,
      ),
    );
    return SeventeenLiveParser.sectionsPage(response.text, cursor: cursor, status: response.statusCode);
  }

  /// One page of the search: a room id or link finds that room, else a keyword
  /// search of current broadcasts.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    if (page != 1) return const LivePage<LiveRoom>(items: []);
    final text = keyword.trim();
    final roomId = SeventeenLiveParser.roomIdFromUrl(text) ?? SeventeenLiveParser.normalizeRoomId(text);
    if (roomId != null) {
      try {
        return LivePage<LiveRoom>(items: [await _refresh(roomId)]);
      } on SiteNotFoundError {
        return const LivePage<LiveRoom>(items: []);
      }
    }
    final query = SeventeenLiveParser.searchKeyword(text);
    if (query.isEmpty || SeventeenLiveParser.isUrl(text)) return const LivePage<LiveRoom>(items: []);
    final response = await http.send(
      LiveRequest.get(
        Uri.https(_api, '/api/v1/liveStreams/search', {'query': query}),
        headers: SeventeenLiveParser.catalogHeaders,
        site: siteId,
      ),
    );
    return LivePage<LiveRoom>(items: SeventeenLiveParser.searchRooms(response.text, status: response.statusCode));
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _entered(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final playback = await _playback(room);
    return [
      for (final offered in playback.qualities)
        LivePlayQuality(label: offered.label, sort: offered.sort, codec: offered.codec),
    ];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final playback = await _playback(room);
    if (playback.unavailable != null) {
      throw SiteNotFoundError('17live ${room.roomId}: ${playback.unavailable}');
    }
    final headers = SeventeenLiveParser.mediaHeaders(room.roomId);
    final match =
        playback.qualities.where((option) => option.sort == quality.sort).firstOrNull ??
        (playback.qualities.isEmpty ? null : playback.qualities.first);
    if (match == null) throw SiteNotFoundError('17live ${room.roomId}: no quality offered');
    return [
      for (final line in match.lines)
        LivePlayLine(url: line.url, headers: headers, format: StreamFormat.flv, codec: match.codec, lineId: line.cdn),
    ];
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _refresh(room.roomId);
    return room.mergeFrom(fresh);
  }

  /// The playback cache of [room], re-entering it when the cache is absent (a
  /// list card or a bare room id has no streams yet).
  Future<SeventeenLivePlayback> _playback(LiveRoom room) async {
    final cached = SeventeenLivePlayback.from(room.data, room.roomId);
    if (cached != null) return cached;
    final fresh = await _entered(room.roomId);
    return SeventeenLivePlayback.from(fresh.data, room.roomId) ??
        const SeventeenLivePlayback(roomId: '', userId: '', qualities: [], unavailable: 'no data');
  }

  Future<LiveRoom> _entered(String roomId) async {
    final response = await http.send(
      LiveRequest.get(
        Uri.https(_api, '/api/v1/lives/${SeventeenLiveParser.normalizeRoomId(roomId) ?? ''}'),
        headers: SeventeenLiveParser.requestHeaders(roomId),
        site: siteId,
      ),
    );
    return SeventeenLiveParser.enteredRoom(response.text, roomId: roomId, status: response.statusCode);
  }

  Future<LiveRoom> _refresh(String roomId) async {
    final id =
        SeventeenLiveParser.normalizeRoomId(roomId) ?? (throw SiteNotFoundError('17live: not a room id: $roomId'));
    final response = await http.send(
      LiveRequest.get(
        Uri.https(_api, '/api/v1/lives/$id'),
        headers: SeventeenLiveParser.requestHeaders(id),
        site: siteId,
      ),
    );
    return SeventeenLiveParser.room(response.text, roomId: id, status: response.statusCode);
  }
}
