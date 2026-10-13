import 'dart:math';

import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/baidulive/danmaku/baidulive_danmaku.dart';
import 'package:live_sites/src/platforms/baidulive/danmaku/baidulive_session.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_parser.dart';

/// The Baidu Live adapter: the signed PC feed for the directory, and rooms
/// through the searchbox 371 room command.
///
/// Not migrated yet: the replay variants beyond the recording URL. One
/// request serves both detail and play — the room command carries the video
/// URLs, so play reuses the last answer — and the same command names the
/// signed message lists the danmaku session ([connect]) polls.
///
/// The directory is the feed: one signed form POST a page, pages following one
/// feed session for the recommendations and one per channel; a page repeats no
/// room of its session, and the page a session served last is replayed without
/// a request. A later page that is not the session's next is empty, and a
/// non-2xx answer (this tree sends no integrity-token fallback) ends it.
final class BaiduLiveSite with SiteRoomGuard implements LiveSite, LiveDanmakuCapability, LiveAreaCatalog {
  /// A site over [http].
  new({required this.http}) : _feedDevice = 'pc-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}purelivedev';

  /// The HTTP transport.
  final LiveHttp http;

  late final String _deviceId = _newDeviceId();

  /// The feed's device id (`uid`), made once per adapter.
  final String _feedDevice;

  /// The platform's channels, once a first feed page brought them; else the
  /// [BaiduLiveParser.fallbackChannels] list.
  List<BaiduLiveChannel>? _channels;

  /// The feed session of the recommendations (key `''`) and of each channel (by
  /// its id), each paged in turn.
  final Map<String, _BaiduSequence> _sequences = {};

  String? _lastBody;
  String? _lastRoomId;

  @override
  String get siteId => SiteIds.baiduLive;

  @override
  String get id => SiteIds.baiduLive;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.baiduLive, displayName: '百度直播', homeUrl: 'https://live.baidu.com');

  /// The channels: the platform's, once a first feed page brought them, else
  /// the fixed fallback list. No request.
  @override
  Future<List<LiveArea>> getAreas() async =>
      BaiduLiveParser.channelAreas(_channels ?? BaiduLiveParser.fallbackChannels);

  /// Page [page] of the recommendations (the first channel, in a session of
  /// their own).
  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) {
    final channel = (_channels ?? BaiduLiveParser.fallbackChannels).first;
    return _directory(page: page, channel: channel, key: '');
  }

  /// Page [page] of [area]'s feed; an area that is not one of the catalog's
  /// channels is a caller error, refused before a request.
  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) {
    final id = area.id.trim();
    final channels = _channels ?? BaiduLiveParser.fallbackChannels;
    for (final channel in channels) {
      if (channel.id == id) {
        return _directory(page: page, channel: channel, key: id);
      }
    }
    throw SiteError.invalidRoomId(area.id);
  }

  /// Page [page] of [channel]'s feed ([key] its session): page 1 starts a new
  /// session, and each later page must be that session's next (any other page
  /// is empty, without a request). A page keeps the rooms the session has not
  /// shown yet and has more while it was full, brought a new room and moved the
  /// session on; the page a session served last is replayed without a request.
  /// The first page's channel list replaces the catalog. A page below 1 is
  /// empty; one above `maxPage` is a [RangeError].
  Future<LivePage<LiveRoom>> _directory({
    required int page,
    required BaiduLiveChannel channel,
    required String key,
  }) async {
    if (page < 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    if (page == 1) {
      _sequences[key] = _BaiduSequence();
    }
    final sequence = _sequences[key];
    if (sequence != null && page == sequence.lastPage && sequence.last != null) {
      return sequence.last!;
    }
    if (sequence == null || page != sequence.nextPage) {
      return const LivePage<LiveRoom>(items: []);
    }
    if (page > BaiduLiveParser.maxPage) {
      throw RangeError.range(page, 1, BaiduLiveParser.maxPage, 'page');
    }
    final previous = sequence.refreshIndex;
    final result = await _feed(
      channel,
      page: page,
      sessionId: sequence.sessionId,
      refreshIndex: page == 1 ? 1 : previous + 1,
    );
    if (result.channels.isNotEmpty) {
      _channels = result.channels;
    }
    final fresh = [
      for (final room in result.rooms)
        if (sequence.seen.add(room.roomId)) room,
    ];
    final hasMore = result.hasMore && fresh.isNotEmpty && (page == 1 || result.refreshIndex > previous);
    final served = LivePage<LiveRoom>(items: fresh, hasMore: hasMore, nextPage: hasMore ? page + 1 : null);
    sequence
      ..sessionId = result.sessionId
      ..refreshIndex = result.refreshIndex
      ..nextPage = hasMore ? page + 1 : page
      ..lastPage = page
      ..last = served;
    return served;
  }

  /// One signed feed page of [channel]. The body is form-encoded as the site
  /// sends it (empty fields bare, `sid&`).
  Future<({List<LiveRoom> rooms, List<BaiduLiveChannel> channels, String sessionId, int refreshIndex, bool hasMore})>
  _feed(BaiduLiveChannel channel, {required int page, required String sessionId, required int refreshIndex}) async {
    final form = BaiduLiveParser.feedForm(
      channel: channel,
      first: page == 1,
      deviceId: _feedDevice,
      now: DateTime.now(),
      sessionId: sessionId,
      refreshIndex: refreshIndex,
    );
    final response = await http.send(
      LiveRequest.custom(
        url: BaiduLiveParser.feedUrl,
        method: 'POST',
        body: BaiduLiveParser.feedBody(form),
        headers: BaiduLiveParser.feedHeaders,
        site: id,
      ),
    );
    return BaiduLiveParser.page(response.text, status: response.statusCode);
  }

  /// Baidu Live has no keyword search: a room id or room link is that room
  /// (the room command, one request); anything else, or a later page, is
  /// nothing without a request, and an id the room command does not know is
  /// no result.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    if (page != 1) {
      return const LivePage<LiveRoom>(items: []);
    }
    final roomId = BaiduLiveParser.parseRoomId(keyword.trim());
    if (roomId == null) {
      return const LivePage<LiveRoom>(items: []);
    }
    try {
      return LivePage<LiveRoom>(items: [await _fetch(roomId)]);
    } on SiteNotFoundError {
      return const LivePage<LiveRoom>(items: []);
    }
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _fetch(room.roomId);
    return room.mergeFrom(fresh);
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    final body = await _bodyFor(room.roomId);
    final lines = BaiduLiveParser.playLines(body, roomId: room.roomId);
    final heights = <int>{
      for (final line in lines)
        if (line.height != null) line.height!,
    };
    return [
      for (final (index, height) in (heights.toList()..sort((a, b) => b.compareTo(a))).indexed)
        LivePlayQuality(label: '${height}P', sort: -index),
    ];
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final body = await _bodyFor(room.roomId);
    final lines = BaiduLiveParser.playLines(body, roomId: room.roomId);
    final height = int.tryParse(quality.label.replaceAll('P', ''));
    if (height == null) {
      return lines;
    }
    return lines.where((line) => line.height == height).toList();
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final fresh = await _fetch(room.roomId);
    return room.mergeFrom(fresh);
  }

  /// Opens Baidu Live's chat: the room command names the signed message lists
  /// the session polls. A room whose command gives no valid chat list cannot
  /// be followed, so this ends with a [SiteNotFoundError] rather than an
  /// empty stream. The lists' signatures come from this command; a session
  /// that outlives one ends, and the caller reconnects to a fresh command.
  @override
  Future<LiveDanmakuSession> connect(LiveRoom room) async {
    guardRoom(room);
    final command = BaiduLiveParser.commandOf(await _bodyFor(room.roomId));
    final args = BaiduLiveDanmakuProtocol.danmakuArgs(command, room.roomId);
    if (args == null) {
      throw SiteNotFoundError('baidulive ${room.roomId}: no message list to follow');
    }
    return await BaiduLiveDanmakuSession.connect(args, http);
  }

  Future<LiveRoom> _fetch(String roomId) async {
    final body = await _bodyFor(roomId);
    return BaiduLiveParser.room(body, roomId: roomId);
  }

  /// The room command body, memoised per room so play does not re-request
  /// what the detail just fetched.
  Future<String> _bodyFor(String roomId) async {
    if (_lastRoomId == roomId && _lastBody != null) {
      return _lastBody!;
    }
    final response = await http.send(
      LiveRequest.get(
        Uri.https('mbd.baidu.com', '/searchbox', BaiduLiveParser.roomQuery(roomId, deviceId: _deviceId)),
        headers: BaiduLiveParser.apiHeaders,
        site: id,
      ),
    );
    _lastRoomId = roomId;
    return _lastBody = response.text;
  }

  static String _newDeviceId() {
    final random = Random.secure();
    return 'pc-${[for (var i = 0; i < 12; i++) random.nextInt(36).toRadixString(36)].join()}baidulive';
  }
}

/// One feed session (its id, the page it is on, the rooms it has shown, and the
/// page it served last so a repeat is replayed without a request).
final class _BaiduSequence {
  String sessionId = '';
  int refreshIndex = 0;
  int nextPage = 1;
  int lastPage = 0;
  LivePage<LiveRoom>? last;
  final Set<String> seen = {};
}
