import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/twitcasting/danmaku/twitcasting_session.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_parser.dart';

/// The TwitCasting adapter: channel page + streamserver flow.
///
/// Only `movie.live` is authoritative for on-air state. A password
/// (secret-word) broadcast shows as live with the password restriction.
/// The comment stream is the broadcast's event socket, whose URL the site
/// hands out per broadcast with a signature that lasts about an hour.
///
/// The directory is the site's `top/category` window: one answer of up to
/// sixty broadcasts, paged locally, for the whole site or one of the
/// homepage's tabs.
///
/// Search is the live section (`#tw-search-result-live`) of the site's text
/// search page: one window of up to fifty rows, paged locally like the
/// directory.
final class TwitcastingSite
    with SiteRoomGuard
    implements LiveSite, LiveDanmakuCapability, LiveAreaCatalog, LiveDirectoryCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.twitcasting;

  @override
  String get id => SiteIds.twitcasting;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.twitcasting, displayName: 'TwitCasting', homeUrl: 'https://twitcasting.tv');

  /// The site's tabs, read from its own home page: the tabs *are* the
  /// catalogue, so this one request is also the tab keys a listing accepts.
  @override
  Future<List<LiveArea>> getAreas() async {
    final response = await http.send(
      LiveRequest.get(Uri.https('twitcasting.tv', '/'), headers: TwitcastingParser.headers, site: siteId),
    );
    return TwitcastingParser.areas(response.text, status: response.statusCode);
  }

  /// The whole site's window: `top/category` without a tab, which is the
  /// broadcasts the site itself shows on its front page.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) => _directory('', page);

  /// The window of one homepage tab; a key that is not a tab key is a caller
  /// error, refused before any request.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    final key = area.id.trim();
    if (!TwitcastingParser.areaIdPattern.hasMatch(key)) {
      throw SiteError.invalidRoomId(area.id);
    }
    return _directory(key, page);
  }

  /// One page of a tab's window.
  ///
  /// The site answers a single window of [TwitcastingParser.directoryWindow]
  /// broadcasts, so page 1 asks for it whole and a later page is cut from the
  /// same answer while it is younger than [windowLifetime]; a page past the
  /// window is empty without a request.
  Future<LivePage<LiveRoom>> _directory(String key, int page) async {
    if (page < 1 || page > TwitcastingParser.maxPage) {
      throw RangeError.range(page, 1, TwitcastingParser.maxPage, 'page');
    }
    if ((page - 1) * TwitcastingParser.directoryPageSize >= TwitcastingParser.directoryWindow) {
      return const LivePage<LiveRoom>(items: []);
    }
    final cached = _windows[key];
    final String body;
    if (page > 1 && cached != null && DateTime.now().difference(cached.at) < windowLifetime) {
      body = cached.body;
    } else {
      final response = await http.send(
        LiveRequest.get(
          Uri.https('frontendapi.twitcasting.tv', '/top/category', {
            'id': key,
            'count': '${TwitcastingParser.directoryWindow}',
          }),
          headers: TwitcastingParser.headers,
          site: siteId,
        ),
      );
      if (response.statusCode != 200) {
        throw SiteApiChangedError('twitcasting top/category $key: HTTP ${response.statusCode}');
      }
      body = response.text;
      _windows.remove(key);
      _windows[key] = (at: DateTime.now(), body: body);
      if (_windows.length > _windowLimit) {
        _windows.remove(_windows.keys.first);
      }
    }
    return TwitcastingParser.directory(body, page: page, areaId: key, now: DateTime.now());
  }

  /// How long a window is reused by the pages after the first.
  static const Duration windowLifetime = Duration(seconds: 30);

  /// How many windows are kept at once (the site's tabs, oldest dropped).
  static const int _windowLimit = 8;

  final Map<String, ({DateTime at, String body})> _windows = {};

  /// Live channels matching [keyword]: the site answers one window of
  /// [TwitcastingParser.searchWindow] live rows, so page 1 asks for it and a
  /// later page is cut from the same cached answer while it is younger than
  /// [windowLifetime]; a page past the window is empty without a request. A
  /// channel link finds that channel, live or not, on page 1 (an unknown one
  /// finds nothing); other TwitCasting links find nothing. A blank keyword is
  /// nothing; a page out of range or a keyword over 100 characters is a caller
  /// error, as 3.x refused them.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    const pageSize = TwitcastingParser.directoryPageSize;
    final query = keyword.trim();
    if (page < 1 || page > TwitcastingParser.maxPage || query.length > 100) {
      throw ArgumentError('Invalid TwitCasting search: page $page, ${query.length} characters');
    }
    if (query.isEmpty || (page - 1) * pageSize >= TwitcastingParser.searchWindow) {
      return const LivePage<LiveRoom>(items: []);
    }
    final link = Uri.tryParse(query);
    if (link != null && TwitcastingParser.hosts.contains(link.host.toLowerCase())) {
      final channel = _channelOfLink(link);
      if (channel == null || page != 1) {
        return const LivePage<LiveRoom>(items: []);
      }
      try {
        final room = await getRoomDetail(LiveRoom(platform: SiteIds.twitcasting, roomId: channel));
        return LivePage<LiveRoom>(items: [room]);
      } on SiteNotFoundError {
        return const LivePage<LiveRoom>(items: []);
      }
    }
    return await _search(query, page);
  }

  /// The channel a TwitCasting [link] names: a single path segment that is a
  /// channel name; null for a deeper or unusable path (3.x's `channelFromUri`).
  static String? _channelOfLink(Uri link) {
    if (link.userInfo.isNotEmpty || (link.hasPort && link.port != (link.isScheme('https') ? 443 : 80))) {
      return null;
    }
    final parts = link.pathSegments.where((segment) => segment.isNotEmpty).toList();
    return parts.length == 1 ? TwitcastingParser.channelName(parts.single) : null;
  }

  /// One page of a keyword's search window, cached by keyword like the
  /// directory window.
  Future<LivePage<LiveRoom>> _search(String query, int page) async {
    const pageSize = TwitcastingParser.directoryPageSize;
    final key = 'search|$query';
    final cached = _windows[key];
    if (page > 1 && cached != null && DateTime.now().difference(cached.at) < windowLifetime) {
      return TwitcastingParser.searchPage(cached.body, page: page, pageSize: pageSize);
    }
    final response = await http.send(
      LiveRequest.get(TwitcastingParser.searchUrl(query), headers: TwitcastingParser.headers, site: siteId),
    );
    final result = TwitcastingParser.searchPage(
      response.text,
      page: page,
      pageSize: pageSize,
      status: response.statusCode,
    );
    _windows.remove(key);
    _windows[key] = (at: DateTime.now(), body: response.text);
    if (_windows.length > _windowLimit) {
      _windows.remove(_windows.keys.first);
    }
    return result;
  }

  /// Opens the broadcast's comment stream.
  ///
  /// The socket URL belongs to one broadcast, so it is fetched here rather
  /// than cached: a session opened after the streamer restarted subscribes
  /// to the new broadcast. A room that is not on air has no movie id at all,
  /// which is reported as "no danmaku" instead of an attempt to guess one.
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final movieId = await _movieId(room);
    if (movieId == null) {
      throw SiteNotFoundError('twitcasting ${room.roomId}: not on air, no comment stream');
    }
    return await TwitcastingDanmakuSession.connect(movieId, http);
  }

  /// The broadcast's movie id, read the same way the play-lines path reads
  /// it — from the stream server answer, which names the live broadcast.
  Future<int?> _movieId(LiveRoom room) async {
    final stream = await _stream(_channel(room.roomId));
    return stream.live ? stream.movieId : null;
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final channel = _channel(room.roomId);
    final pageResponse = await http.send(
      LiveRequest.get(Uri.https('twitcasting.tv', '/$channel'), headers: TwitcastingParser.headers, site: id),
    );
    final page = TwitcastingParser.channelPage(
      pageResponse.text,
      roomId: room.roomId,
      channel: channel,
      status: pageResponse.statusCode,
    );
    final stream = await _stream(channel);
    if (!stream.live) {
      return room.mergeFrom(page.room.copyWith(status: LiveStatus.offline));
    }
    final sameBroadcast = page.movieId == null || stream.movieId == null || page.movieId == stream.movieId;
    var merged = page.room.copyWith(status: LiveStatus.live, data: stream);
    if (sameBroadcast && page.liveStartedAt != null) {
      merged = merged.copyWith(startedAt: page.liveStartedAt);
    }
    if (page.secretWord) {
      merged = merged.copyWith(restriction: LiveRestriction.needsLogin);
    }
    return room.mergeFrom(merged);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final stream = await _streamData(room);
    final lines = TwitcastingParser.playLines(stream, _channel(room.roomId));
    final labels = <String>{
      for (final line in lines)
        if (line.lineId != null) line.lineId!,
    };
    return [for (final (index, label) in labels.indexed) LivePlayQuality(label: label, sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final stream = await _streamData(room);
    final lines = TwitcastingParser.playLines(stream, _channel(room.roomId));
    final matching = lines.where((line) => line.lineId == quality.label).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final stream = await _stream(_channel(room.roomId));
    return room.mergeFrom(
      LiveRoom(
        platform: SiteIds.twitcasting,
        roomId: room.roomId,
        status: stream.live ? LiveStatus.live : LiveStatus.offline,
        data: stream,
      ),
    );
  }

  /// The stream data, reusing the one cached in the room.
  Future<({bool live, int? movieId, Map<String, String> streams})> _streamData(LiveRoom room) async {
    final data = room.data;
    if (data is ({bool live, int? movieId, Map<String, String> streams})) {
      return data;
    }
    final stream = await _stream(_channel(room.roomId));
    return stream;
  }

  Future<({bool live, int? movieId, Map<String, String> streams})> _stream(String channel) async {
    final response = await http.send(
      LiveRequest.get(
        Uri.https('twitcasting.tv', '/streamserver.php', {'target': channel, 'mode': 'client', 'player': 'pc_web'}),
        headers: TwitcastingParser.headers,
        site: id,
      ),
    );
    return TwitcastingParser.streamServer(response.text, status: response.statusCode);
  }

  String _channel(String roomId) {
    final channel = TwitcastingParser.channelName(roomId);
    if (channel == null) {
      throw SiteNotFoundError('twitcasting: "${roomId.trim()}" is not a channel');
    }
    return channel;
  }
}
