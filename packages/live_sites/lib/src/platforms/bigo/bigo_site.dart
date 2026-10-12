import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_parser.dart';

/// The Bigo Live adapter: the token → studio flow (the studio API needs a
/// signed anonymous web token), plus the public list.
///
/// Not migrated yet: search, the password/paid detail and the danmaku
/// transport.
final class BigoSite with SiteRoomGuard implements LiveSite, LiveAreaCatalog, LiveDirectoryCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  /// The last web token, reused for refreshes.
  String? _token;

  @override
  String get siteId => SiteIds.bigo;

  @override
  String get id => SiteIds.bigo;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.bigo, displayName: 'Bigo Live', homeUrl: 'https://www.bigo.tv');

  /// The catalogue: one constant area, the public list.
  @override
  Future<List<LiveArea>> getAreas() async => BigoParser.areas();

  /// Page [page] of the public list, which is what the site recommends.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    if (page < 1) {
      throw RangeError.range(page, 1, null, 'page');
    }
    final cards = await _publicList(fresh: page == 1);
    final start = (page - 1) * BigoParser.directoryPageSize;
    if (start >= cards.length) {
      return LivePage<LiveRoom>(items: const [], totalCount: cards.length);
    }
    final end = (start + BigoParser.directoryPageSize).clamp(start, cards.length);
    final hasMore = end < cards.length;
    return LivePage<LiveRoom>(
      items: cards.sublist(start, end),
      hasMore: hasMore,
      nextPage: hasMore ? page + 1 : null,
      totalCount: cards.length,
    );
  }

  /// As [getRecommendRooms]; the site has one area and anything else is a
  /// caller error rather than a request that cannot work.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    if (!BigoParser.isArea(area)) {
      throw SiteError.invalidRoomId(area.id);
    }
    return getRecommendRooms(page: page);
  }

  /// The public list: page 1 asks anew (the pull to refresh) and a later
  /// page reuses the answer while it is younger than [listLifetime], so the
  /// pages of one browse neither repeat nor skip rooms of the first. The
  /// list is a finite snapshot of about twenty rooms, and it is not signed —
  /// no token is spent on it.
  Future<List<LiveRoom>> _publicList({required bool fresh}) async {
    final cached = _list;
    final at = _listAt;
    if (!fresh && cached != null && at != null && DateTime.now().difference(at) < listLifetime) {
      return cached;
    }
    final response = await http.send(
      LiveRequest.get(BigoParser.directoryUrl(), headers: BigoParser.headers, site: siteId),
    );
    final cards = BigoParser.directory(response.text, status: response.statusCode);
    _list = cards;
    _listAt = DateTime.now();
    return cards;
  }

  /// How long the public list is reused after it arrived.
  static const Duration listLifetime = Duration(seconds: 30);

  List<LiveRoom>? _list;
  DateTime? _listAt;

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('bigo search lands with its migration');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final studio = await _studio(room.roomId);
    return room.mergeFrom(BigoParser.room(studio));
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    return const [LivePlayQuality(label: '原画')];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    // A play is a token's *first* use by definition: the media playlist only
    // rides that answer, so this asks with a fresh token rather than one a
    // detail or refresh has already spent.
    final studio = await _studio(room.roomId, freshToken: true);
    final hls = studio.hls;
    if (hls == null) {
      throw SiteNotFoundError('bigo ${room.roomId}: no playlist');
    }
    return [BigoParser.line(hls, studio.siteId)];
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final studio = await _studio(room.roomId);
    return room.mergeFrom(BigoParser.room(studio));
  }

  /// The studio of [siteId] with the token chain (server time → token →
  /// studio). The token is reused across detail and refresh calls;
  /// [freshToken] spends a new one, because a token's first use is the only
  /// answer that carries the media playlist.
  Future<
    ({
      String siteId,
      bool alive,
      bool needsLogin,
      bool password,
      bool paid,
      String? title,
      String? nick,
      String? avatar,
      String? cover,
      String? area,
      String? hls,
    })
  >
  _studio(String siteId, {bool freshToken = false}) async {
    if (freshToken) {
      _token = null;
    }
    final token = _token ?? await _fetchToken();
    final response = await http.send(
      LiveRequest.custom(
        url: Uri.https(BigoParser.apiHost, '/official_website/studio/getInternalStudioInfo', {
          'siteId': siteId,
          'verify': '',
          'token': token,
        }),
        method: 'POST',
        body: '',
        headers: BigoParser.headers,
        site: id,
      ),
    );
    return BigoParser.studio(response.text, requestedSiteId: siteId, status: response.statusCode);
  }

  /// A fresh anonymous token: server time, then the keyed status call.
  Future<String> _fetchToken() async {
    final timeCallback = BigoParser.callback();
    final time = await http.send(
      LiveRequest.get(
        Uri.https(BigoParser.tokenHost, '/v1/webjs/t', {'callback': timeCallback}),
        headers: BigoParser.headers,
        site: id,
      ),
    );
    final timestamp = BigoParser.serverTime(time.text, callback: timeCallback, status: time.statusCode);
    final statusCallback = BigoParser.callback();
    final status = await http.send(
      LiveRequest.get(
        Uri.https(BigoParser.tokenHost, '/v1/webjs/status', {
          'callback': statusCallback,
          'data': await BigoParser.tokenData(timestamp),
        }),
        headers: BigoParser.headers,
        site: id,
      ),
    );
    return _token = BigoParser.token(status.text, callback: statusCallback, status: status.statusCode);
  }
}
