import 'dart:collection';

// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_playback_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/capabilities/live_room_refresh.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/capabilities/live_status_check.dart';
import 'package:live_sites/src/core/live_site.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/baidulive/api/baidulive_endpoints.dart';
import 'package:live_sites/src/platforms/baidulive/api/baidulive_http.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_manifest.dart';
import 'package:live_sites/src/platforms/baidulive/capabilities/baidulive_area_provider.dart';
import 'package:live_sites/src/platforms/baidulive/capabilities/baidulive_discovery_provider.dart';
import 'package:live_sites/src/platforms/baidulive/capabilities/baidulive_link_resolver.dart';
import 'package:live_sites/src/platforms/baidulive/capabilities/baidulive_playback_provider.dart';
import 'package:live_sites/src/platforms/baidulive/capabilities/baidulive_room_provider.dart';
import 'package:live_sites/src/platforms/baidulive/capabilities/baidulive_room_refresh.dart';
import 'package:live_sites/src/platforms/baidulive/capabilities/baidulive_search_provider.dart';
import 'package:live_sites/src/platforms/baidulive/capabilities/baidulive_status_check.dart';
import 'package:live_sites/src/platforms/baidulive/danmaku/baidulive_danmaku_session.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_failure.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_play_parser.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How many rooms are remembered to complete later answers (3.x kept every
/// one; the same cap as 3.x's `knownLimit`).
const int _knownLimit = 512;

/// How many room answers are kept as stream data (one per room entered; the
/// oldest goes first).
const int _entryLimit = 32;

/// The Baidu Live (百度直播) adapter: manifest + capability discovery +
/// lifecycle (ARCHITECTURE.md §7.2); parsing in `parsers/`, the chat in
/// `danmaku/`.
///
/// A room is one broadcast, its id the room id as asked for (3.x's identity).
/// Anonymous, like 3.x: no cookie, no account; every request carries
/// [BaiduliveEndpoints.apiHeaders]. The requests are 3.x's:
/// - the catalog is the feed's channel list (3.x's fixed list until the first
///   feed page brings the platform's), without a request;
/// - a directory page is one signed feed POST; pages follow one feed session
///   for the recommendations and one per channel (30-6), a page repeats no
///   room of the session, and the page a session served last is replayed
///   without a request;
/// - search is one room command for a room id or link, on page 1; Baidu has
///   no public keyword search;
/// - a room, its playback data and, while live, its chat lists come from one
///   room command.
///
/// The adapter remembers the cards and rooms it saw (3.x's `_known`), to fill
/// what a later answer for the same room leaves out.
///
/// Failures are [BaiduliveFailure]s; nothing is disguised as an offline room.
/// A paid, forbidden or banned broadcast keeps its state and is marked (30-5);
/// an ended one plays its recording when there is one (30-4).
final class BaiduliveSite implements LiveSite {
  /// Creates the adapter over [http]. Like 3.x, the feed names this client
  /// `pc-<clock>purelivedev` and every room command a new
  /// `pc-<clock>baidulive`; [deviceId] replaces both (tests), [now] the clock.
  /// [preferH264] reads "优先 H.264" (on by default, the setting shared with
  /// 8-8, 14-5, 22-3 and 33-2) at each call: on, a room's H.264 qualities come
  /// before the others, so the default is H.264 and H.265 is only picked by
  /// hand; off, the best tier comes first (30-2, see
  /// [BaidulivePlayParser.ordered]).
  factory BaiduliveSite({
    required BaiduliveHttp http,
    DateTime Function()? now,
    String? deviceId,
    bool Function()? preferH264,
  }) => BaiduliveSite._(http, now ?? DateTime.now, deviceId, preferH264 ?? _on);

  BaiduliveSite._(this.http, this.now, this._deviceId, this.preferH264);

  static bool _on() => true;

  /// Transport (the feed and the room command alike).
  final BaiduliveHttp http;

  /// Injectable clock (the feed's `timestamp`, the client names, the room
  /// command's `_`).
  final DateTime Function() now;

  /// Whether the quality menu puts H.264 first ("优先 H.264").
  final bool Function() preferH264;

  final String? _deviceId;

  /// The feed's device id, made once per adapter (3.x).
  late final String feedDevice = BaiduliveEndpoints.feedDevice(_deviceId, now);

  /// A room command's device id: a new one per call (3.x), unless the
  /// constructor injected one.
  String roomDevice() => BaiduliveEndpoints.roomDevice(_deviceId, now);

  /// Rooms remembered, by room id, oldest first.
  final LinkedHashMap<String, BaiduliveRoom> _known = LinkedHashMap();

  /// The feed session of the recommendations ([_recommendations]) and of each
  /// channel, by its id (30-6: the recommendations and the "推荐" channel no
  /// longer share one).
  final Map<String, _Sequence> _sequences = {};

  /// The room answer each room was entered with, by room id: the stream data
  /// the playback capability hands out (3.x kept it in `LiveRoom.data`).
  final Map<String, BaiduliveRoom> _entries = {};

  /// The session key of the recommendations (no channel id is empty).
  static const String _recommendations = '';

  /// The platform's channels, once a first feed page brought them.
  List<BaiduliveCategory>? _channels;

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => baiduliveManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  /// The catalog's channels: the platform's own list once a first feed page
  /// brought it, else 3.x's fixed list. Never a request.
  List<BaiduliveCategory> channels() => _channels ?? BaiduliveEndpoints.fallbackCategories;

  /// The areas of [channels] (3.x's one category's children).
  List<LiveArea> areas() => BaiduliveRoomParser.areas(channels());

  // Requests ------------------------------------------------------------------

  /// One signed feed page of [channel] (3.x's `directory`), with
  /// [BaiduliveEndpoints.feedHeaders]. The body is encoded as 3.x's client
  /// sent it (`Uri(queryParameters:).query`): empty fields bare (`sid&`).
  Future<BaidulivePage> _feed(
    BaiduliveCategory channel, {
    required int page,
    required String sessionId,
    required int refreshIndex,
  }) async {
    final form = BaiduliveEndpoints.feedForm(
      channel: channel,
      first: page == 1,
      deviceId: feedDevice,
      now: now(),
      sessionId: sessionId,
      refreshIndex: refreshIndex,
    );
    final response = await http.post(
      BaiduliveEndpoints.feedUrl,
      body: BaiduliveEndpoints.feedBody(form),
      headers: BaiduliveEndpoints.feedHeaders,
    );
    return BaiduliveRoomParser.page(response.text, status: response.status);
  }

  /// Room [roomId] from one room command, filled from what was seen of it
  /// before and remembered (3.x's `_detail`).
  Future<BaiduliveRoom> _room(String roomId) async {
    final query = BaiduliveEndpoints.roomQuery(roomId, deviceId: roomDevice(), now: now());
    final response = await http.get(BaiduliveEndpoints.roomUrlOf(query), headers: BaiduliveEndpoints.apiHeaders);
    var room = BaiduliveRoomParser.room(response.text, expectedRoomId: roomId, status: response.status);
    if (_known[roomId] case final known?) room = room.enrich(known);
    _remember(room);
    return room;
  }

  void _remember(BaiduliveRoom room) {
    _known
      ..remove(room.roomId)
      ..[room.roomId] = room;
    while (_known.length > _knownLimit) {
      _known.remove(_known.keys.first);
    }
  }

  /// [roomId] as a room id or room link (3.x accepted both); anything else is
  /// not-found without a request (3.x refused it as an identity error).
  String _checkedId(String roomId) =>
      BaiduliveEndpoints.parseRoomId(roomId) ??
      (throw BaiduliveFailure(BaiduliveFailureKind.notFound, 'not a room id: ${roomId.trim()}'));

  // Catalog and directory -----------------------------------------------------

  /// The channel of [areaId]: null is the first (the recommendations); a
  /// channel not in the catalog is a caller error, refused before any request
  /// (3.x checked the area's platform and type too, which an id alone cannot
  /// carry here).
  BaiduliveCategory _channel(String? areaId) {
    final channels = this.channels();
    if (areaId == null) return channels.first;
    final id = areaId.trim();
    return channels.where((channel) => channel.id == id).firstOrNull ??
        (throw BaiduliveFailure(BaiduliveFailureKind.invalidArgument, 'area "$areaId" is not a Baidu Live channel'));
  }

  /// Page [page] of [areaId]'s feed (3.x): page 1 starts a new feed session,
  /// and each later page must be the next of that session (any other page is
  /// empty, without a request). A page keeps the rooms the session has not
  /// shown yet and has more while it was full, brought a new room and moved
  /// the session on. The first page's channel list replaces the catalog. A
  /// page below 1 is empty.
  ///
  /// 30-6: the recommendations (no [areaId]) have a session of their own,
  /// apart from the "推荐" channel's; asking again for the page a session
  /// served last replays it without a request (3.x answered it empty and ended
  /// the list). A page past [BaiduliveEndpoints.maxPage] that a session really
  /// continues is a caller error (3.x's `RangeError`).
  Future<({List<LiveRoom> rooms, bool hasMore})> directory(int page, {String? areaId}) async {
    if (page < 1) return (rooms: const <LiveRoom>[], hasMore: false);
    final channel = _channel(areaId);
    final key = areaId == null ? _recommendations : channel.id;
    if (page == 1) _sequences[key] = _Sequence();
    final sequence = _sequences[key];
    if (sequence != null && page == sequence.lastPage) {
      if (sequence.last case final replayed?) return replayed;
    }
    if (sequence == null || page != sequence.nextPage) return (rooms: const <LiveRoom>[], hasMore: false);
    if (page > BaiduliveEndpoints.maxPage) {
      throw BaiduliveFailure(BaiduliveFailureKind.invalidArgument, 'page $page is past ${BaiduliveEndpoints.maxPage}');
    }
    final previous = sequence.refreshIndex;
    final result = await _feed(
      channel,
      page: page,
      sessionId: sequence.sessionId,
      refreshIndex: page == 1 ? 1 : previous + 1,
    );
    if (result.categories.isNotEmpty) _channels = result.categories;
    final fresh = [
      for (final room in result.rooms)
        if (sequence.seen.add(room.roomId)) room,
    ];
    final hasMore = result.hasMore && fresh.isNotEmpty && (page == 1 || result.refreshIndex > previous);
    fresh.forEach(_remember);
    final served = (rooms: [for (final room in fresh) BaiduliveRoomParser.liveRoom(room)], hasMore: hasMore);
    sequence
      ..sessionId = result.sessionId
      ..refreshIndex = result.refreshIndex
      ..nextPage = hasMore ? page + 1 : page
      ..lastPage = page
      ..last = served;
    return served;
  }

  /// The first [pageSize] rooms of page [page] of [areaId]. A page or a size
  /// below 1 gives nothing without a request; an area the catalog does not
  /// name is a caller error.
  Future<({List<LiveRoom> rooms, bool hasMore})> areaRooms(String areaId, {int page = 1, int pageSize = 30}) async {
    if (page < 1 || pageSize < 1) return (rooms: const <LiveRoom>[], hasMore: false);
    final served = await directory(page, areaId: areaId);
    return (rooms: served.rooms.take(pageSize).toList(growable: false), hasMore: served.hasMore);
  }

  /// The first [pageSize] rooms of page [page] of the recommendations (the
  /// first channel, in a session of their own, 30-6). A page or a size below
  /// 1 gives nothing without a request.
  Future<({List<LiveRoom> rooms, bool hasMore})> recommend(int page, int pageSize) async {
    if (page < 1 || pageSize < 1) return (rooms: const <LiveRoom>[], hasMore: false);
    final served = await directory(page);
    return (rooms: served.rooms.take(pageSize).toList(growable: false), hasMore: served.hasMore);
  }

  // Search --------------------------------------------------------------------

  /// 3.x's search: a room id or room link finds that room, live or not, on
  /// page 1 (one room command; nothing when there is no such room). Baidu has
  /// no public keyword search, so anything else finds nothing, without a
  /// request — and no later page ever has.
  Future<({List<LiveRoom> rooms, bool hasMore})> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final roomId = BaiduliveEndpoints.parseRoomId(keyword.trim());
    if (roomId == null || page != 1 || pageSize < 1) return (rooms: const <LiveRoom>[], hasMore: false);
    try {
      return (rooms: [BaiduliveRoomParser.liveRoom(await _room(roomId))], hasMore: false);
    } on BaiduliveFailure catch (failure) {
      if (failure.kind != BaiduliveFailureKind.notFound) rethrow;
      return (rooms: const <LiveRoom>[], hasMore: false);
    }
  }

  // Rooms ---------------------------------------------------------------------

  /// Room entry: the room with its stream data and, while live, its chat
  /// arguments (M5.26) from the same room command; the answer is kept as the
  /// data the playback capability hands out. 3.x's refresh and recording
  /// answers are this one room command too, so a refresh brings the chat
  /// arguments of the same answer and a connection whose signature expired can
  /// start again with new lists (E05.4).
  Future<LiveRoom> detail(String roomId) async {
    final room = await _room(_checkedId(roomId));
    _entries
      ..remove(room.roomId)
      ..[room.roomId] = room;
    while (_entries.length > _entryLimit) {
      _entries.remove(_entries.keys.first);
    }
    return BaiduliveRoomParser.liveRoom(room, withData: true);
  }

  // Streams -------------------------------------------------------------------

  /// The qualities [roomId] offers now (see [BaidulivePlayParser.qualities]:
  /// 原画 and the heights of a live broadcast, the recording of an ended one;
  /// H.264 first while "优先 H.264" is on): the answer its room entry brought,
  /// without a request, else a new room command, which is kept for the lines
  /// that follow. A room the platform called offline says so without one, and
  /// a room that cannot be played says why.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async =>
      BaidulivePlayParser.qualities(await _streamSource(roomId, keep: true), preferH264: preferH264());

  /// The lines of [quality] (by its id; a 3.x id too, see
  /// [BaidulivePlayParser.qualityIdFromLegacy]; null: the quality the menu
  /// puts first), with the media headers.
  ///
  /// The answer room entry kept serves the lines that follow a qualities
  /// request, and is spent by it: 3.x's recovery never reused the lines it had
  /// handed out but asked a new room command, which every later request here
  /// is. The same quality id must still be offered; a quality the room no
  /// longer has is stream-unavailable.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async =>
      BaidulivePlayParser.linesFor(await _streamSource(roomId, keep: false), quality, preferH264: preferH264());

  Future<BaiduliveRoom> _streamSource(String roomId, {required bool keep}) async {
    final id = _checkedId(roomId);
    final entry = _entries[id];
    if (entry != null) {
      if (!keep) _entries.remove(id);
      return entry;
    }
    // A room the platform called announced or offline plays nothing (3.x read
    // that off the detail's status, without a request).
    if (_known[id] case final known?
        when known.state == BaiduliveState.preview || known.state == BaiduliveState.offline) {
      throw known.unavailable ?? BaiduliveFailure(BaiduliveFailureKind.streamUnavailable, '$id is ${known.state.name}');
    }
    final room = await _room(id);
    // A qualities read hands its answer to the lines that follow it.
    if (keep) _entries[room.roomId] = room;
    return room;
  }

  // Capability wiring ---------------------------------------------------------

  BaiduliveRoomProvider? _roomProvider;
  BaiduliveAreaProvider? _area;
  BaiduliveDiscoveryProvider? _discovery;
  BaiduliveSearchProvider? _search;
  BaidulivePlaybackProvider? _playback;
  BaiduliveDanmakuProvider? _danmaku;
  BaiduliveLinkResolver? _link;
  BaiduliveRoomRefresh? _refresh;
  BaiduliveStatusCheck? _status;

  /// The capability of type [T], or null when Baidu Live does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _roomProvider ??= BaiduliveRoomProvider(site: this);
    final area = _area ??= BaiduliveAreaProvider(site: this);
    final discovery = _discovery ??= BaiduliveDiscoveryProvider(site: this);
    final search = _search ??= BaiduliveSearchProvider(site: this);
    final playback = _playback ??= BaidulivePlaybackProvider(site: this);
    final danmaku = _danmaku ??= BaiduliveDanmakuProvider(site: this);
    final link = _link ??= BaiduliveLinkResolver(site: this);
    final refresh = _refresh ??= BaiduliveRoomRefresh(site: this);
    final status = _status ??= BaiduliveStatusCheck(refresh: refresh);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => area as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LiveDanmakuProvider) => danmaku as T,
      const (LiveLinkResolver) => link as T,
      const (LiveRoomRefresh) => refresh as T,
      const (LiveStatusCheck) => status as T,
      _ => null,
    };
  }
}

/// One feed session (3.x's `_BaiduDirectorySequence`), with the page it served
/// last (30-6).
final class _Sequence {
  String sessionId = '';
  int refreshIndex = 0;
  int nextPage = 1;
  int lastPage = 0;
  ({List<LiveRoom> rooms, bool hasMore})? last;
  final Set<String> seen = {};
}
