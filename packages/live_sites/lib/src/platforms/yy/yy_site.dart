import 'dart:async';

// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/yy/api/yy_endpoints.dart';
import 'package:live_sites/src/platforms/yy/api/yy_http.dart';
import 'package:live_sites/src/platforms/yy/capabilities/yy_area_provider.dart';
import 'package:live_sites/src/platforms/yy/capabilities/yy_discovery_provider.dart';
import 'package:live_sites/src/platforms/yy/capabilities/yy_link_resolver.dart';
import 'package:live_sites/src/platforms/yy/capabilities/yy_playback_provider.dart';
import 'package:live_sites/src/platforms/yy/capabilities/yy_room_provider.dart';
import 'package:live_sites/src/platforms/yy/capabilities/yy_search_provider.dart';
import 'package:live_sites/src/platforms/yy/danmaku/yy_danmaku_session.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_failure.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_json.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_play_parser.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_room_parser.dart';
import 'package:live_sites/src/platforms/yy/yy_manifest.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F]');

/// The channel behind a room (3.x's `YyRoomData`): streams are requested by
/// the canonical channel, which a room asked for by its short number keeps
/// apart from its identity.
final class YyRoomData {
  /// Wraps the channel.
  const YyRoomData({required this.sid, required this.ssid});

  /// Canonical top channel (`sid`).
  final String sid;

  /// Sub channel (`ssid`); the same as [sid] for every room seen so far.
  final String ssid;

  @override
  String toString() => 'YyRoomData($sid, $ssid)';
}

/// What the danmaku connection joins (3.x's `YyDanmakuArgs`): the top
/// channel and the sub channel it enters.
final class YyDanmakuArgs {
  /// Wraps the channels.
  const YyDanmakuArgs({required this.topSid, required this.subSid});

  /// Top channel (`sid`).
  final int topSid;

  /// Sub channel (`ssid`); the same as [topSid] for every room seen so far.
  final int subSid;

  @override
  String toString() => 'YyDanmakuArgs($topSid, $subSid)';
}

/// The YY (欢聚时代) adapter (3.x's `YySite`; parsing in `parsers/`, the chat
/// in `danmaku/`): manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2).
///
/// API requests carry 3.x's browser headers and the user's cookie when one
/// is stored; there is no anonymous session. By default streams come from
/// the anonymous mobile HLS route (what 3.x users got), and stream-manager
/// (FLV) stands in when mobile HLS has nothing; [flvFirst] turns the order
/// round. FLV qualities carry every CDN line of their stream. Failures are
/// [YyFailure]s; nothing is disguised as an offline room.
final class YySite implements LiveSite {
  /// Creates the adapter over [http]. [connect] makes the chat's socket
  /// (default [webSocketConnect]); [cookie] supplies the user's cookie;
  /// [flvFirst] lists stream-manager's qualities first; [now] (the
  /// stream-manager sequence and the leases) is injectable for tests.
  YySite({
    required this.http,
    this.connect = webSocketConnect,
    String Function()? cookie,
    this.flvFirst = false,
    DateTime Function()? now,
  }) : _cookie = cookie ?? _noCookie,
       _now = now ?? DateTime.now;

  static String _noCookie() => '';

  /// Transport.
  final YyHttp http;

  /// How the chat's socket is connected.
  final SocketConnector connect;

  /// Whether qualities come from stream-manager (FLV: lower latency, the
  /// platform's names 蓝光, 高清, 流畅, URLs signed for 10 minutes) with
  /// mobile HLS standing in, instead of mobile HLS first (3.x's
  /// `高清 · 720p`, `流畅 · 360p`).
  final bool flvFirst;

  final String Function() _cookie;
  final DateTime Function() _now;

  /// The areas of the catalog (by area id), from [areas].
  final Map<String, LiveArea> _areasById = {};

  /// The page of each area (by area id), from the catalog.
  final Map<String, Uri> _areaPages = {};

  /// The listing module of each area whose page was read (null: none).
  final Map<String, YyModule?> _modules = {};

  /// Area pages just read for their module whose rooms are in the page;
  /// taken by the next [areaRooms].
  final Map<String, String> _pages = {};

  /// Area names by `biz`, learnt from the area modules seen so far; the
  /// first area of a `biz` names it (3.x's `bizAreaNameMap`).
  final Map<String, String> _areaNames = {};

  /// The canonical channel of each room id whose room was read (a short
  /// number's differs from it), most recent last.
  final Map<String, YyChannel> _channels = {};

  /// How many room ids [_channels] keeps.
  static const int _channelLimit = 4096;

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => yyManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Requests ------------------------------------------------------------------

  /// The user's cookie ('' when none), control characters removed.
  String _login() => _cookie().replaceAll(_controlCharacters, '').trim();

  /// A GET with 3.x's API headers.
  Future<YyResponse> _get(Uri url) => http.get(url, headers: YyEndpoints.apiHeaders(cookie: _login()));

  // Catalog -------------------------------------------------------------------

  /// The areas of the catalog: the categories of the header and their areas
  /// from `getCategory`. The short-video page (小视频) is no live area and is
  /// left out; an area's listing module is read from its page when the area
  /// is opened ([areaRooms]), not here.
  Future<List<LiveArea>> areas() async {
    final header = await _get(YyEndpoints.header());
    final tabs = YyRoomParser.categoryTabs(header.text, status: header.status);
    final listings = await Future.wait([for (final tab in tabs) _areasOf(tab.id, tab.name)]);
    final result = <LiveArea>[];
    for (final entry in listings.expand((list) => list)) {
      if (YyRoomParser.isShortVideoPage(entry.page)) continue;
      _areasById[entry.area.areaId] = entry.area;
      if (entry.page != null) _areaPages[entry.area.areaId] = entry.page!;
      result.add(entry.area);
    }
    return result;
  }

  /// The areas of category [id] and their pages, remembered for [_module].
  Future<List<YyAreaEntry>> _areasOf(String id, String name) async {
    final response = await _get(YyEndpoints.category(id));
    return YyRoomParser.areas(response.text, categoryId: id, categoryName: name, status: response.status);
  }

  /// The page of [area] (found in its category's `getCategory` when the
  /// catalog was not loaded).
  Future<Uri> _areaPage(LiveArea area) async {
    final id = area.areaId.trim();
    final hasParent = area.parentAreaId?.trim().isNotEmpty ?? false;
    if (!_areaPages.containsKey(id) && hasParent) {
      await _areasOf(area.parentAreaId!.trim(), area.parentAreaName ?? '');
    }
    return _areaPages[id] ?? (throw YyFailure(YyFailureKind.invalidArgument, 'area $id names no page in the catalog'));
  }

  /// The HTML of an area [page].
  Future<String> _readPage(Uri page) async {
    final response = await _get(page);
    YyJson.checkPage(response.status, 'area page ${page.path}');
    return response.text;
  }

  /// An area without a JSON listing: a page whose `pageInfo` has none, or
  /// no `pageInfo` at all (小视频, a short-video page).
  static const YyModule _noListing = (moduleId: 0, biz: 'null', subBiz: 'null');

  /// The listing module of [area]: its stored `shortName` (3.x's areas and
  /// follows), else the one read from its page, else its page is read now.
  /// The page of an area without listing is kept for its first page of
  /// rooms ([_pages]).
  Future<YyModule> _module(LiveArea area) async {
    final stored = YyRoomParser.moduleOf(area.shortName ?? '');
    if (stored != null) return _learn(stored, area);
    final id = area.areaId.trim();
    if (!_modules.containsKey(id)) {
      final html = await _readPage(await _areaPage(area));
      final module = _modules[id] = YyRoomParser.pageInfo(html);
      if (module == null || !YyRoomParser.hasListing(module)) _pages[id] = html;
    }
    return _learn(_modules[id] ?? _noListing, area);
  }

  /// [module], its `biz` now naming [area] for recommendations and details
  /// (the first area of a `biz` wins).
  YyModule _learn(YyModule module, LiveArea area) {
    final name = area.areaName.trim();
    if (name.isNotEmpty && YyRoomParser.hasListing(module)) _areaNames.putIfAbsent(module.biz, () => name);
    return module;
  }

  // Listings ------------------------------------------------------------------

  /// A page of rooms of the area [areaId]: `more/page.action` with the
  /// area's module. An area without a JSON listing (`moduleId: 0`: 手机直播,
  /// 综合, 英雄联盟) renders its rooms in its page: the first page lists those
  /// cards (the page read for the module, else read again), later pages are
  /// empty.
  Future<List<LiveRoom>> areaRooms(String areaId, {int page = 1, int pageSize = 30}) async {
    if (page < 1) throw YyFailure(YyFailureKind.invalidArgument, 'page $page is below 1');
    final area = _areasById[areaId.trim()];
    if (area == null) {
      throw YyFailure(YyFailureKind.invalidArgument, 'area "$areaId" is not in the YY catalog');
    }
    final module = await _module(area);
    if (!YyRoomParser.hasListing(module)) {
      if (page > 1) return const [];
      final html = _pages.remove(area.areaId.trim()) ?? await _readPage(await _areaPage(area));
      return _withStreams(YyRoomParser.pageRooms(html, area: area.areaName));
    }
    final response = await _get(
      YyEndpoints.pageAction(
        page: page,
        pageSize: pageSize,
        moduleId: module.moduleId,
        biz: module.biz,
        subBiz: module.subBiz,
      ),
    );
    return _withStreams(YyRoomParser.roomList(response.text, area: area.areaName, status: response.status));
  }

  /// The home listing (`biz=other`); cards name their area by `biz` when an
  /// area module taught it or the preset names it
  /// ([YyEndpoints.bizAreaNames]), else leave it empty (3.x showed the raw
  /// `biz`, `other` on every card).
  Future<List<LiveRoom>> recommendRooms({int page = 1, int pageSize = 30}) async {
    if (page < 1) throw YyFailure(YyFailureKind.invalidArgument, 'page $page is below 1');
    final response = await _get(YyEndpoints.recommendAction(page: page, pageSize: pageSize));
    return _withStreams(YyRoomParser.roomList(response.text, areaNames: Map.of(_areaNames), status: response.status));
  }

  /// Live rooms (`t=120`). A blank keyword gives nothing without a request.
  Future<List<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    final response = await _searchTab(keyword, '120', page);
    return response == null ? const [] : _withStreams(YyRoomParser.searchRooms(response.text, status: response.status));
  }

  /// Streamers (`t=1`), live or not.
  Future<List<LiveAnchor>> searchAnchors(String keyword, {int page = 1}) async {
    final response = await _searchTab(keyword, '1', page);
    return response == null ? const [] : YyRoomParser.searchAnchors(response.text, status: response.status);
  }

  Future<YyResponse?> _searchTab(String keyword, String tab, int page) async {
    if (page < 1) throw YyFailure(YyFailureKind.invalidArgument, 'page $page is below 1');
    final text = keyword.trim();
    if (text.isEmpty) return null;
    return await _get(YyEndpoints.search(text, tab: tab, page: page));
  }

  /// Every parsed room carries the channel its streams enter by, as the
  /// room's stream handle.
  List<LiveRoom> _withStreams(Iterable<YyLiveRoom> entries) => [
    for (final (:room, :channel) in entries)
      room.copyWith(
        runtime: RoomRuntime(
          streamHandle: YyRoomData(sid: channel.sid, ssid: channel.ssid),
        ),
      ),
  ];

  // Rooms ---------------------------------------------------------------------

  /// Room entry: `liveInfoDetail` of the channel (under its canonical number
  /// once the room page named it). When it is not live (`data: null`, also
  /// the answer for unknown channels and short numbers) the room page tells
  /// them apart: the 404 page is not-found, a short number is looked up
  /// again under its canonical channel, anything else is offline with the
  /// page's streamer, title and danmaku arguments.
  Future<LiveRoom> detail(String roomId) => _detail(roomId, always: true);

  /// A refresh: `liveInfoDetail`, 3.x's one request per follow; an offline
  /// room's page once, so an unknown channel is not-found and a short number
  /// is followed to its canonical channel (3.x showed both offline for
  /// ever).
  Future<LiveRoom> refreshRoom(String roomId) => _detail(roomId, always: false);

  Future<LiveRoom> _detail(String roomId, {required bool always}) async {
    final id = roomId.trim();
    if (!YyEndpoints.isChannel(id)) {
      throw YyFailure(YyFailureKind.notFound, 'room id $id is not a channel number');
    }
    final known = _channels[id];
    final live = await _liveDetail(known?.sid ?? id, requestedId: id);
    if (live != null) {
      _remember(id, live.channel);
      return live.room.copyWith(
        runtime: RoomRuntime(
          streamHandle: YyRoomData(sid: live.channel.sid, ssid: live.channel.ssid),
          danmakuHandle: _danmakuArgs(live.channel),
        ),
      );
    }
    if (!always && known != null) return _offline(id, page: null, channel: known);
    final response = await _get(YyEndpoints.roomPage(id));
    final page = YyRoomParser.roomPage(response.text, status: response.status);
    final channel = (sid: page.sid, ssid: page.ssid);
    _remember(id, channel);
    if (page.sid != id && known?.sid != page.sid) {
      final canonical = await _liveDetail(page.sid, requestedId: id);
      if (canonical != null) {
        _remember(id, canonical.channel);
        return canonical.room.copyWith(
          runtime: RoomRuntime(
            streamHandle: YyRoomData(sid: canonical.channel.sid, ssid: canonical.channel.ssid),
            danmakuHandle: _danmakuArgs(canonical.channel),
          ),
        );
      }
    }
    return _offline(id, page: page, channel: channel);
  }

  Future<YyLiveRoom?> _liveDetail(String sid, {required String requestedId}) async {
    final response = await _get(YyEndpoints.liveInfoDetail(sid));
    return YyRoomParser.liveDetail(
      response.text,
      requestedId: requestedId,
      areaNames: _areaNames,
      status: response.status,
    );
  }

  /// The offline room, its runtime handles attached.
  LiveRoom _offline(String id, {required YyRoomPage? page, required YyChannel channel}) =>
      YyRoomParser.offlineRoom(requestedId: id, page: page).copyWith(
        runtime: RoomRuntime(
          streamHandle: YyRoomData(sid: channel.sid, ssid: channel.ssid),
          danmakuHandle: _danmakuArgs(channel),
        ),
      );

  /// The danmaku arguments of a channel (3.x's, numbers).
  static YyDanmakuArgs _danmakuArgs(YyChannel channel) =>
      YyDanmakuArgs(topSid: int.tryParse(channel.sid) ?? 0, subSid: int.tryParse(channel.ssid) ?? 0);

  void _remember(String roomId, YyChannel channel) {
    _channels.remove(roomId);
    _channels[roomId] = channel;
    if (_channels.length > _channelLimit) _channels.remove(_channels.keys.first);
  }

  // Streams -------------------------------------------------------------------

  /// The channel [roomId] plays: the canonical channel a room read before
  /// named, else a fresh room entry.
  Future<YyChannel> _channelOf(String roomId) async {
    final id = roomId.trim();
    if (!YyEndpoints.isChannel(id)) {
      throw YyFailure(YyFailureKind.notFound, 'room id $id is not a channel number');
    }
    final known = _channels[id];
    if (known != null) return known;
    await _detail(id, always: true);
    return _channels[id] ?? (sid: id, ssid: id);
  }

  /// The qualities of [roomId]: the mobile HLS ones by default (3.x users'),
  /// else stream-manager's (FLV, asked at gear 1). With [flvFirst] the other
  /// way round. A channel with neither is stream-unavailable when a route
  /// said it has no stream, else the first failure is thrown.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async {
    final channel = await _channelOf(roomId);
    YyFailure? failure;
    var noStream = false;
    for (final route in flvFirst ? [_flvQualities, _mobileQualities] : [_mobileQualities, _flvQualities]) {
      try {
        return await route(channel);
      } on YyFailure catch (error) {
        if (error.kind == YyFailureKind.streamUnavailable) {
          noStream = true;
        } else {
          failure ??= error;
        }
      }
    }
    if (noStream || failure == null) {
      throw const YyFailure(YyFailureKind.streamUnavailable, 'no stream on mobile HLS or stream-manager');
    }
    throw failure;
  }

  /// stream-manager's qualities (one request at gear 1); stream-unavailable
  /// when it lists none.
  Future<List<LivePlayQuality>> _flvQualities(YyChannel channel) async {
    final qualities = YyPlayParser.qualities((await _streamManager(channel, 1)).streams);
    if (qualities.isEmpty) {
      throw const YyFailure(YyFailureKind.streamUnavailable, 'stream-manager: no stream');
    }
    return qualities;
  }

  /// Both mobile rates at once (3.x's `_getMobileHlsQualities`). A rate that
  /// fails is left out; when every rate failed, the first failure is thrown,
  /// and when the answers had no stream, stream-unavailable.
  Future<List<LivePlayQuality>> _mobileQualities(YyChannel channel) async {
    final answers = await Future.wait([for (final rate in YyEndpoints.mobileHlsRates) _mobileAnswer(channel, rate)]);
    final qualities = YyPlayParser.mobileQualities([
      for (final answer in answers) (rate: answer.rate, hls: answer.hls),
    ]);
    if (qualities.isNotEmpty) return qualities;
    final errors = [
      for (final answer in answers)
        if (answer.error != null) answer.error!,
    ];
    if (errors.length == answers.length) throw errors.first;
    throw const YyFailure(YyFailureKind.streamUnavailable, 'mobile HLS: no stream');
  }

  Future<({String rate, YyMobileHls? hls, YyFailure? error})> _mobileAnswer(YyChannel channel, String rate) async {
    try {
      return (rate: rate, hls: await _mobile(channel, rate), error: null);
    } on YyFailure catch (error) {
      return (rate: rate, hls: null, error: error);
    }
  }

  /// The lines of [quality] (the best mobile quality when it is null).
  ///
  /// A mobile quality asks the mobile route at its rate (3.x); when that has
  /// no stream or fails, stream-manager plays the same tier as FLV (4000 is
  /// gear 2 高清, 1200 gear 1 流畅, as measured), without confirming the
  /// quality. A stream-manager quality asks stream-manager at its gear, adds
  /// the other CDN lines of the served stream; when that fails or has no
  /// URL, the mobile route at 4000 (a quality of rate 2000 or more) or 1200
  /// plays instead, as in 3.x.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async {
    final channel = await _channelOf(roomId);
    final id = quality?.qualityId?.trim() ?? '';
    if (id.isEmpty) {
      final qualities = await qualitiesOf(roomId);
      return await linesOf(roomId, quality: qualities.first);
    }
    if (id.startsWith(YyEndpoints.mobileHlsPrefix)) {
      final rate = id.substring(YyEndpoints.mobileHlsPrefix.length);
      YyFailure? failure;
      var noStream = false;
      try {
        final hls = await _mobile(channel, rate);
        if (hls != null) return [YyPlayParser.mobileLine(hls, cookie: _login())];
        noStream = true;
      } on YyFailure catch (error) {
        failure = error;
      }
      try {
        final lines = await _flv(channel, (int.tryParse(rate) ?? 0) >= 2000 ? 2 : 1);
        if (lines.isNotEmpty) return lines;
        noStream = true;
      } on YyFailure catch (error) {
        failure ??= error;
      }
      if (noStream || failure == null) {
        throw YyFailure(YyFailureKind.streamUnavailable, 'mobile HLS $rate and stream-manager: no stream');
      }
      throw failure;
    }
    final gear = int.tryParse(id);
    if (gear != null) {
      try {
        final lines = await _flv(channel, gear);
        if (lines.isNotEmpty) return lines;
      } on YyFailure {
        // Mobile HLS below, as in 3.x.
      }
    }
    final rate = (quality?.platformOrder ?? 0) >= 2000
        ? YyEndpoints.mobileHlsRates.last
        : YyEndpoints.mobileHlsRates.first;
    final hls = await _mobile(channel, rate);
    if (hls == null) {
      throw const YyFailure(YyFailureKind.streamUnavailable, 'no stream on stream-manager or mobile HLS');
    }
    return [YyPlayParser.mobileLine(hls, cookie: _login())];
  }

  /// The FLV lines of [gear]: stream-manager's answer (the server picks the
  /// line), then the served gear asked again on each other CDN line of its
  /// stream ([YyPlayParser.otherLines], one request each, concurrently). An
  /// extra line that fails or serves another gear is left out.
  Future<List<LivePlayLine>> _flv(YyChannel channel, int gear) async {
    final answer = await _streamManager(channel, gear);
    final first = YyPlayParser.resolution(answer.streams, issuedAt: answer.issuedAt, cookie: _login());
    final served = int.tryParse(first.appliedGear ?? '');
    final others = YyPlayParser.otherLines(answer.streams);
    if (first.lines.isEmpty || served == null || others.isEmpty) return first.lines;
    final extra = await Future.wait([for (final line in others) _otherLine(channel, served, line)]);
    return YyPlayParser.withLines(first, extra.nonNulls);
  }

  Future<({List<LivePlayLine> lines, String? appliedGear})?> _otherLine(YyChannel channel, int gear, int line) async {
    try {
      final answer = await _streamManager(channel, gear, line: line);
      return YyPlayParser.resolution(answer.streams, issuedAt: answer.issuedAt, cookie: _login());
    } on YyFailure {
      return null;
    }
  }

  /// One stream-manager request for [gear] on CDN [line] (-1: the server's
  /// choice): a JSON body sent as `text/plain`, anonymous (`uid=0`),
  /// `sequence` the time in milliseconds.
  Future<({Map<String, dynamic> streams, DateTime issuedAt})> _streamManager(
    YyChannel channel,
    int gear, {
    int line = -1,
  }) async {
    final issuedAt = _now();
    final sequence = issuedAt.millisecondsSinceEpoch;
    final response = await http.postText(
      YyEndpoints.streamManager(sid: channel.sid, ssid: channel.ssid, sequence: sequence),
      body: YyEndpoints.streamManagerJson(
        sid: channel.sid,
        ssid: channel.ssid,
        gear: gear,
        sequence: sequence,
        line: line,
      ),
      headers: YyEndpoints.streamManagerHeaders(channel.sid, channel.ssid, cookie: _login()),
    );
    return (streams: YyPlayParser.streams(response.text, status: response.status), issuedAt: issuedAt);
  }

  /// The mobile HLS answer at [rate]; null when the channel has no stream.
  Future<YyMobileHls?> _mobile(YyChannel channel, String rate) async {
    final response = await http.get(
      YyEndpoints.mobileHls(sid: channel.sid, ssid: channel.ssid, rate: rate),
      headers: YyEndpoints.mobileHlsHeaders(channel.sid, channel.ssid, cookie: _login()),
    );
    return YyPlayParser.mobileHls(response.text, status: response.status);
  }

  // Capability wiring ---------------------------------------------------------

  YyRoomProvider? _room;
  YyAreaProvider? _area;
  YyDiscoveryProvider? _discovery;
  YySearchProvider? _search;
  YyPlaybackProvider? _playback;
  YyDanmakuProvider? _danmaku;
  YyLinkResolver? _link;

  /// The capability of type [T], or null when YY does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= YyRoomProvider(site: this);
    final area = _area ??= YyAreaProvider(site: this);
    final discovery = _discovery ??= YyDiscoveryProvider(site: this);
    final search = _search ??= YySearchProvider(site: this);
    final playback = _playback ??= YyPlaybackProvider(site: this);
    final danmaku = _danmaku ??= YyDanmakuProvider(site: this);
    final link = _link ??= const YyLinkResolver();
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => area as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LiveDanmakuProvider) => danmaku as T,
      const (LiveLinkResolver) => link as T,
      _ => null,
    };
  }
}
