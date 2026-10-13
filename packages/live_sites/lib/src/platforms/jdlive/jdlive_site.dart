import 'dart:math';

import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/jdlive/danmaku/jdlive_danmaku.dart';
import 'package:live_sites/src/platforms/jdlive/danmaku/jdlive_session.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_parser.dart';

/// The JD Live adapter: rooms through the h5 `getImmediatePlayToM` play
/// answer and the featured list (`liveListWithTabToM`), plus the `liveauth`
/// chat socket.
///
/// Not migrated yet: the playlist validation pass. Search filters its own
/// per-keyword sequence of the featured list (3.x's `search:<query>`).
final class JdLiveSite
    with SiteRoomGuard
    implements LiveSite, LiveDanmakuCapability, LiveAreaCatalog, LiveDirectoryCapability {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  /// The last card of each broadcast, filling empty display fields of
  /// later play answers.
  final Map<String, Map<String, Object?>> _known = {};
  String? _lastBody;
  String? _lastLiveId;

  @override
  String get siteId => SiteIds.jdLive;

  @override
  String get id => SiteIds.jdLive;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.jdLive, displayName: '京东直播', homeUrl: 'https://m.jd.com/live');

  /// The catalogue: one area, and it is constant — the featured list — so no
  /// request is spent finding it out.
  @override
  Future<List<LiveArea>> getAreas() async => JdLiveParser.areas();

  /// Page [page] of the featured list — the site has only this one list.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) => _directory(page);

  /// As [getRecommendRooms]; an area that is not the featured list is a
  /// caller error, refused before any request.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    if (!JdLiveParser.isArea(area)) {
      throw SiteError.invalidRoomId(area.id);
    }
    return _directory(page);
  }

  /// Page [page] of the featured list.
  ///
  /// The list pages by a *sequence* rather than by page number: page 1 starts
  /// one at the clock's time, every later page sends the count the previous
  /// page reported together with that same time, and a broadcast the sequence
  /// already listed is not listed again. A stateless `page: N` request is
  /// served by walking the sequence — the pages asked before are kept, so
  /// "next page" costs one request — and a page the sequence has ended before
  /// is empty rather than an error.
  Future<LivePage<LiveRoom>> _directory(int page) {
    if (page < 1 || page > JdLiveParser.maxPage) {
      throw RangeError.range(page, 1, JdLiveParser.maxPage, 'page');
    }
    if (page == 1) {
      // Page 1 is the pull to refresh: it starts the sequence anew.
      _sequence = _JdLiveSequence(DateTime.now().millisecondsSinceEpoch);
    }
    return _walk(_sequence, page);
  }

  /// Walks [sequence] up to [page], asking only the pages it has not cached,
  /// and answers the page's rooms and whether another may follow.
  Future<LivePage<LiveRoom>> _walk(_JdLiveSequence sequence, int page) async {
    for (var current = 1; current <= page; current++) {
      if (sequence.pages[current] != null) {
        continue;
      }
      if (sequence.ended || !sequence.counts.containsKey(current)) {
        // The listing ran out before this page (or the sequence was restarted),
        // which is an empty page rather than an error.
        return const LivePage<LiveRoom>(items: []);
      }
      final count = sequence.counts[current]!;
      final response = await http.send(
        LiveRequest.get(
          JdLiveParser.listUrl(page: current, count: count, timestamp: sequence.startedAt, now: DateTime.now()),
          headers: JdLiveParser.apiHeaders,
          site: siteId,
        ),
      );
      final answer = JdLiveParser.directory(response.text, page: current, after: count, status: response.statusCode);
      final fresh = <LiveRoom>[];
      for (final entry in answer.entries) {
        _known[entry.room.roomId] = entry.card;
        if (sequence.listed.add(entry.room.roomId)) {
          fresh.add(entry.room);
        }
      }
      final more = answer.hasMore && fresh.isNotEmpty;
      sequence.pages[current] = fresh;
      if (more) {
        sequence.counts[current + 1] = answer.nextCount;
      } else {
        sequence.ended = true;
      }
    }
    final rooms = sequence.pages[page] ?? const <LiveRoom>[];
    final hasMore = !sequence.ended;
    return LivePage<LiveRoom>(items: rooms, hasMore: hasMore, nextPage: hasMore ? page + 1 : null);
  }

  /// The sequence the current browse walks; page 1 replaces it.
  _JdLiveSequence _sequence = _JdLiveSequence(0);

  /// The sequence each keyword's search walks (3.x's `search:<query>`); the
  /// oldest drops past [_searchLimit].
  final Map<String, _JdLiveSequence> _searches = {};

  static const int _searchLimit = 32;

  /// 3.x's search: a broadcast id or room link is that room (page 1 only; an
  /// unknown one is nothing); another keyword filters its own sequence's page
  /// [page] of the featured list by id, account, shop name and title (case
  /// ignored), the first 30. A blank keyword, a page below 1, or a link of
  /// another site gives nothing without a request; a later page whose sequence
  /// never started is empty without a request.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    if (page < 1 || page > JdLiveParser.maxPage) {
      throw RangeError.range(page, 1, JdLiveParser.maxPage, 'page');
    }
    final raw = keyword.trim();
    if (raw.isEmpty) {
      return const LivePage<LiveRoom>(items: []);
    }
    final liveId = JdLiveParser.liveIdOf(raw);
    if (liveId != null) {
      if (page != 1) {
        return const LivePage<LiveRoom>(items: []);
      }
      try {
        return LivePage<LiveRoom>(
          items: [await getRoomDetail(LiveRoom(platform: SiteIds.jdLive, roomId: liveId))],
        );
      } on SiteNotFoundError {
        return const LivePage<LiveRoom>(items: []);
      }
    }
    if (_isLink(raw)) {
      return const LivePage<LiveRoom>(items: []);
    }
    final query = raw.toLowerCase();
    if (page == 1) {
      _searches
        ..remove(query)
        ..[query] = _JdLiveSequence(DateTime.now().millisecondsSinceEpoch);
      if (_searches.length > _searchLimit) {
        _searches.remove(_searches.keys.first);
      }
    }
    final sequence = _searches[query];
    if (sequence == null) {
      return const LivePage<LiveRoom>(items: []);
    }
    final result = await _walk(sequence, page);
    final matches = result.items.where((room) => JdLiveParser.matches(room, query)).take(30);
    return LivePage<LiveRoom>(items: List.unmodifiable(matches));
  }

  /// Whether [input] is a link (`scheme://…`) rather than a keyword. 3.x
  /// filtered the list with it, which never matched.
  static bool _isLink(String input) {
    final uri = Uri.tryParse(input);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final liveId = _numeric(room.roomId);
    final data = await _play(liveId);
    final fresh = JdLiveParser.room(data, liveId: liveId, known: _known[liveId]);
    _known[liveId] = data;
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final liveId = _numeric(room.roomId);
    final data = await _play(liveId);
    final status = JdLiveParser.statusOf(data['status']);
    final qualities = <LivePlayQuality>[];
    if (status == LiveStatus.live) {
      if (_has(data['h5VideoUrl'], '.m3u8')) {
        qualities.add(const LivePlayQuality(label: 'HLS'));
      }
      if (_has(data['videoUrl'], '.flv') || _has(data['pcVideoUrl'], '.flv')) {
        qualities.add(const LivePlayQuality(label: 'FLV'));
      }
    } else if (status == LiveStatus.replay) {
      qualities.add(const LivePlayQuality(label: '原画'));
    }
    return qualities;
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final liveId = _numeric(room.roomId);
    final data = await _play(liveId);
    final status = JdLiveParser.statusOf(data['status']);
    final lines = JdLiveParser.playLines(data, liveId, status: status);
    if (quality.label == 'HLS') {
      final hls = lines.where((line) => line.format == StreamFormat.hls).toList();
      return hls.isEmpty ? lines : hls;
    }
    if (quality.label == 'FLV') {
      final flv = lines.where((line) => line.format == StreamFormat.flv).toList();
      return flv.isEmpty ? lines : flv;
    }
    return lines;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final liveId = _numeric(room.roomId);
    final data = await _play(liveId);
    return room.mergeFrom(JdLiveParser.room(data, liveId: liveId, known: _known[liveId]));
  }

  /// Opens the `liveauth` chat for [room].
  ///
  /// A token opens one socket, so every connect POSTs `liveauth` anew (the
  /// page does the same after a socket error). A handshake the server refuses
  /// becomes a [SiteNotFoundError] with its reason, minus the socket URL's
  /// token.
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final liveId = _numeric(room.roomId);
    return await JdLiveDanmakuSession.connect(await _liveauth(liveId), liveId: liveId);
  }

  Future<JdLiveChatAuth> _liveauth(String liveId) async {
    final fields = await JdLiveDanmakuProtocol.liveauthFields(
      liveId,
      now: DateTime.now(),
      nonce: JdLiveDanmakuProtocol.nonce(Random.secure()),
    );
    final response = await http.send(
      LiveRequest.form(
        JdLiveDanmakuProtocol.authUrl,
        fields: fields,
        headers: JdLiveDanmakuProtocol.authHeaders,
        site: id,
      ),
    );
    try {
      return JdLiveDanmakuProtocol.auth(response.text, status: response.statusCode);
    } on FormatException catch (error) {
      throw SiteNotFoundError(JdLiveDanmakuProtocol.redact(error.message));
    }
  }

  Future<Map<String, Object?>> _play(String liveId) async {
    if (_lastLiveId == liveId && _lastBody != null) {
      return JdLiveParser.data(_lastBody!, what: 'getImmediatePlayToM');
    }
    final response = await http.send(
      LiveRequest.get(
        JdLiveParser.playUrl(liveId, now: DateTime.now()),
        headers: JdLiveParser.mediaHeaders(liveId),
        site: id,
      ),
    );
    _lastLiveId = liveId;
    _lastBody = response.text;
    return JdLiveParser.data(response.text, status: response.statusCode, what: 'getImmediatePlayToM');
  }

  String _numeric(String roomId) {
    final liveId = JdLiveParser.liveIdOf(roomId);
    if (liveId == null) {
      throw SiteNotFoundError('jdlive: "${roomId.trim()}" is not a broadcast id');
    }
    return liveId;
  }

  static bool _has(Object? value, String suffix) => (value?.toString() ?? '').contains(suffix);
}

/// One browse of the featured list: the sequence the site pages by.
///
/// The site walks its list by count and time rather than by page number, so
/// the pages a caller asked for are kept here: the first request starts the
/// sequence, and every later page sends the count the previous one reported
/// with the sequence's own start time. [listed] is what keeps a broadcast
/// from appearing on two pages of the same browse.
final class _JdLiveSequence {
  /// A sequence started at [startedAt] (Unix milliseconds).
  new(this.startedAt) : counts = {1: 0};

  /// When the browse began, sent with every page.
  final int startedAt;

  /// The count each page is asked after.
  final Map<int, int> counts;

  /// The rooms each page answered with.
  final Map<int, List<LiveRoom>> pages = {};

  /// The broadcasts this browse already listed.
  final Set<String> listed = {};

  /// Whether the site said there is no page after the last one walked.
  bool ended = false;
}
