import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/pandalive/danmaku/pandalive_danmaku.dart';
import 'package:live_sites/src/platforms/pandalive/danmaku/pandalive_session.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_parser.dart';

/// The PandaLive adapter: member/bj + live/play flow, the directory, and the
/// Centrifugo chat joined with a `live/play` guest token.
///
/// Not migrated yet: the password/fan-room refusals detail.
final class PandaLiveSite
    with SiteRoomGuard
    implements LiveSite, LiveDanmakuCapability, LiveDirectoryCapability, LiveAreaCatalog {
  /// A site over [http].
  new({required this.http});

  /// The HTTP transport.
  final LiveHttp http;

  @override
  String get siteId => SiteIds.pandalive;

  @override
  String get id => SiteIds.pandalive;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.pandalive, displayName: 'PandaTV', homeUrl: 'https://www.pandalive.co.kr');

  /// The catalogue is *constant* — the two areas 3.x's picker offered, with
  /// no request at all.
  @override
  Future<List<LiveArea>> getAreas() async => PandaLiveParser.areas();

  /// Page [page] (1–1000) of the public directory: one `live/index` POST of
  /// thirty rooms by popularity.
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) => _directory(PandaLiveParser.publicAreaId, page);

  /// As [getRecommendRooms], for the new broadcasters when [area] is that
  /// area; any other area is a caller error refused before any request.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) =>
      _directory(PandaLiveParser.checkArea(area), page);

  Future<LivePage<LiveRoom>> _directory(String areaId, int page) async {
    PandaLiveParser.checkPage(page);
    final response = await http.send(
      LiveRequest.form(
        Uri.https(PandaLiveParser.apiHost, '/v1/live/index'),
        fields: PandaLiveParser.directoryForm(page, areaId: areaId),
        headers: {...PandaLiveParser.headers, 'referer': PandaLiveParser.directoryReferer},
        site: id,
      ),
    );
    return PandaLiveParser.livePage(response.text, page: page, status: response.statusCode);
  }

  /// 3.x's search, in order: a room link finds that broadcaster on page 1;
  /// another URL, or a keyword shorter than 2 or longer than 100 characters,
  /// finds nothing; otherwise the BJ search (`live/bj_list`) runs *before* the
  /// LIVE search (`live/index`) — the gateway was seen to stall one of two
  /// parallel POSTs — each with its own size (half the page live, the rest
  /// broadcasters, at most 50 each). Live cards come first, a broadcaster
  /// once; one source failing leaves the other's rows. On page 1 a keyword
  /// that is a broadcaster id puts that broadcaster first. A page below 1 or
  /// over 1000, or a control-character keyword, is a caller error.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    if (page < 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final query = keyword.trim();
    final linked = PandaLiveParser.roomIdFromUrl(query);
    if (linked != null) {
      if (page > 1) {
        return const LivePage<LiveRoom>(items: []);
      }
      try {
        return LivePage<LiveRoom>(items: [await _refresh(linked)]);
      } on SiteNotFoundError {
        return const LivePage<LiveRoom>(items: []);
      }
    }
    if (Uri.tryParse(query)?.hasScheme ?? false) {
      return const LivePage<LiveRoom>(items: []);
    }
    if (query.length < PandaLiveParser.minKeywordLength || query.length > PandaLiveParser.maxKeywordLength) {
      return const LivePage<LiveRoom>(items: []);
    }
    PandaLiveParser.checkPage(page);
    PandaLiveParser.checkKeyword(query);
    const size = PandaLiveParser.pageSize;
    final exact = page == 1 ? PandaLiveParser.normalizeUserId(query) : null;
    const liveSize = size > 1 ? (size + 1) ~/ 2 : 0;
    final broadcasterSize = (size - liveSize).clamp(1, PandaLiveParser.maxSourceSize);
    List<LiveRoom>? broadcasters;
    List<LiveRoom>? live;
    SiteError? broadcasterError;
    SiteError? liveError;
    try {
      final response = await http.send(
        LiveRequest.form(
          Uri.https(PandaLiveParser.apiHost, '/v1/live/bj_list'),
          fields: PandaLiveParser.broadcasterSearchForm(query, page: page, size: broadcasterSize),
          headers: {...PandaLiveParser.headers, 'referer': PandaLiveParser.searchReferer('bj', query)},
          site: id,
        ),
      );
      broadcasters = PandaLiveParser.broadcasterPage(
        response.text,
        page: page,
        size: broadcasterSize,
        status: response.statusCode,
      ).items;
    } on SiteError catch (error) {
      broadcasterError = error;
    }
    if (liveSize > 0) {
      try {
        final response = await http.send(
          LiveRequest.form(
            Uri.https(PandaLiveParser.apiHost, '/v1/live/index'),
            fields: PandaLiveParser.liveSearchForm(query, page: page, size: liveSize),
            headers: {...PandaLiveParser.headers, 'referer': PandaLiveParser.searchReferer('live', query)},
            site: id,
          ),
        );
        live = PandaLiveParser.livePage(response.text, page: page, size: liveSize, status: response.statusCode).items;
      } on SiteError catch (error) {
        liveError = error;
      }
    }
    var failure = liveError ?? broadcasterError;
    final seen = <String>{};
    final rooms = [
      for (final room in [...?live, ...?broadcasters])
        if (seen.add(room.roomId.toLowerCase())) room,
    ];
    if (exact != null) {
      final index = rooms.indexWhere((room) => room.roomId.toLowerCase() == exact.toLowerCase());
      if (index >= 0) {
        rooms.insert(0, rooms.removeAt(index));
      } else {
        try {
          rooms.insert(0, await _refresh(exact));
        } on SiteNotFoundError {
          // Not a broadcaster after all.
        } on SiteError catch (error) {
          failure ??= error;
        }
      }
    }
    if (rooms.isEmpty && failure != null) {
      throw failure;
    }
    return LivePage<LiveRoom>(items: List.unmodifiable(rooms));
  }

  /// The follow-refresh room of broadcaster [userId]: one `member/bj`.
  Future<LiveRoom> _refresh(String userId) async => PandaLiveParser.room(await _member(userId));

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final member = await _member(room.roomId);
    return room.mergeFrom(PandaLiveParser.room(member));
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final masters = await _masters(room.roomId);
    return [for (final (index, _) in masters.indexed) LivePlayQuality(label: 'HLS-$index', sort: -index)];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final lines = PandaLiveParser.playLines(await _masters(room.roomId), room.roomId);
    final matching = lines.where((line) => line.lineId == quality.label).toList();
    return matching.isEmpty ? lines : matching;
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final member = await _member(room.roomId);
    return room.mergeFrom(PandaLiveParser.room(member));
  }

  /// Opens the Centrifugo chat for [room].
  ///
  /// A `live/play` POST hands the guest token and the chat channel (the
  /// broadcaster's number), asked fresh on every connect. A broadcast the
  /// answer refuses (ended, adult, password, fans only, not live) becomes a
  /// [SiteNotFoundError]; the socket then connects with the token.
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final response = await http.send(
      LiveRequest.form(
        Uri.https(PandaLiveParser.apiHost, '/v1/live/play'),
        fields: PandaLiveParser.playForm(room.roomId),
        headers: {...PandaLiveParser.headers, 'referer': PandaLiveParser.roomUrl(room.roomId)},
        site: id,
      ),
    );
    final ({String channel, String token}) grant;
    try {
      grant = PandaLiveDanmakuProtocol.grant(response.text, status: response.statusCode);
    } on PandaLiveChatRefusal catch (refusal) {
      throw SiteNotFoundError('pandalive ${room.roomId}: $refusal');
    } on FormatException catch (error) {
      throw SiteApiChangedError('pandalive ${room.roomId}: ${error.message}');
    }
    return await PandaLiveDanmakuSession.connect(grant.channel, grant.token);
  }

  Future<
    ({String userId, int index, String nick, String? avatar, bool live, String? title, Map<String, Object?> media})
  >
  _member(String roomId) async {
    final response = await http.send(
      LiveRequest.form(
        Uri.https(PandaLiveParser.apiHost, '/v1/member/bj'),
        fields: PandaLiveParser.memberForm(roomId),
        headers: {...PandaLiveParser.headers, 'referer': PandaLiveParser.roomUrl(roomId)},
        site: id,
      ),
    );
    return PandaLiveParser.member(response.text, userId: roomId, status: response.statusCode);
  }

  Future<List<String>> _masters(String roomId) async {
    final response = await http.send(
      LiveRequest.form(
        Uri.https(PandaLiveParser.apiHost, '/v1/live/play'),
        fields: PandaLiveParser.playForm(roomId),
        headers: {...PandaLiveParser.headers, 'referer': PandaLiveParser.roomUrl(roomId)},
        site: id,
      ),
    );
    final masters = PandaLiveParser.masters(response.text, status: response.statusCode);
    if (masters.isEmpty) {
      throw SiteNotFoundError('pandalive $roomId: no master playlist');
    }
    return masters;
  }
}
