// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_play_lease_lookup.dart';
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
import 'package:live_sites/src/platforms/inke/api/inke_endpoints.dart';
import 'package:live_sites/src/platforms/inke/api/inke_http.dart';
import 'package:live_sites/src/platforms/inke/capabilities/inke_area_provider.dart';
import 'package:live_sites/src/platforms/inke/capabilities/inke_discovery_provider.dart';
import 'package:live_sites/src/platforms/inke/capabilities/inke_link_resolver.dart';
import 'package:live_sites/src/platforms/inke/capabilities/inke_play_lease_lookup.dart';
import 'package:live_sites/src/platforms/inke/capabilities/inke_playback_provider.dart';
import 'package:live_sites/src/platforms/inke/capabilities/inke_room_provider.dart';
import 'package:live_sites/src/platforms/inke/capabilities/inke_room_refresh.dart';
import 'package:live_sites/src/platforms/inke/capabilities/inke_search_provider.dart';
import 'package:live_sites/src/platforms/inke/capabilities/inke_status_check.dart';
import 'package:live_sites/src/platforms/inke/inke_manifest.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_failure.dart';
import 'package:live_sites/src/platforms/inke/parsers/inke_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The Inke (映客) adapter (parsing in `parsers/`): manifest + capability
/// discovery + lifecycle (ARCHITECTURE.md §7.2).
///
/// Anonymous, like the website: no cookie and no account, and no danmaku —
/// the platform has no chat the adapter could join, so no
/// `LiveDanmakuProvider` is offered. Every request carries
/// [InkeEndpoints.headers] and goes as `inke`. The requests are:
/// - the recommendations and the room lists are the app's hot list
///   `api/live/simpleall` (one page) and the website's showcases
///   `web/Live_top_pc` and `web/Live_channel_pc` (the areas);
/// - a nickname search filters those three lists; a uid or room link finds
///   that room;
/// - room entry reads `web/live_share_pc` and, for a live room, the app's
///   `api/live/now_publish`, whose answer is kept as the room's stream
///   handle;
/// - streams come from the room entry's answer while it is fresh (see
///   [answerReuse]), else a fresh `now_publish`; when the app gives no line
///   for the H.264 quality, the website's showcases are looked through for
///   the broadcast (the fallback 3.x played from).
///
/// Failures are [InkeFailure]s; nothing is disguised as an offline room.
final class InkeSite implements LiveSite {
  /// Creates the adapter over [http]. [preferH264] reads "优先 H.264" (on by
  /// default) at each call: on, a room's H.264 quality
  /// ([InkeEndpoints.flvQualityId]) comes before the original HEVC one
  /// ([InkeEndpoints.originQualityId]), so it is the default; off, the
  /// original comes first when there is one. [now] (the leases and the
  /// answers' age) is injectable for tests.
  InkeSite({required this.http, bool Function()? preferH264, DateTime Function()? now})
    : _preferH264 = preferH264 ?? _on,
      _now = now ?? DateTime.now;

  /// How long the room entry's `now_publish` answer serves a play of that
  /// room instead of a new request (its lines are signed for hours): the
  /// first play right after entering costs no request. Recoveries re-resolve
  /// with a fresh answer.
  static const Duration answerReuse = Duration(seconds: 30);

  /// How many rooms' stream data is kept; the oldest entry is dropped.
  static const int _streamLimit = 64;

  /// Transport.
  final InkeHttp http;

  final bool Function() _preferH264;
  final DateTime Function() _now;

  /// The stream data of the room whose entry was read last, by uid: the
  /// qualities and lines the capabilities hand out until the next entry.
  final Map<String, InkeRoomData> _streams = {};

  static bool _on() => true;

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => inkeManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Catalog and directory -----------------------------------------------------

  /// The areas: the website's top list and then its channels, from
  /// `Live_channel_pc`.
  Future<List<LiveArea>> areas() async {
    final response = await http.get(InkeEndpoints.channelsUrl);
    return InkeRoomParser.areas(response.text, status: response.status);
  }

  /// The rooms of area [areaId]: the website's top list, or a channel's
  /// showcase — one page each. A page after the first is empty, without a
  /// request. A page below 1 is a caller error; an id that is neither the top
  /// list nor a channel key is a caller error too, and a listed channel the
  /// showcase does not hold is not-found.
  Future<({List<LiveRoom> rooms, bool hasMore})> areaRooms(String areaId, {int page = 1}) async {
    if (page < 1) throw InkeFailure(InkeFailureKind.invalidArgument, 'page $page is below 1');
    if (page > 1) return (rooms: const <LiveRoom>[], hasMore: false);
    if (areaId == InkeEndpoints.topAreaId) {
      final response = await http.get(InkeEndpoints.topUrl);
      return (rooms: InkeRoomParser.topPage(response.text, status: response.status), hasMore: false);
    }
    if (InkeEndpoints.isChannelKey(areaId)) {
      final response = await http.get(InkeEndpoints.channelsUrl);
      return (
        rooms: InkeRoomParser.channelPage(response.text, tabKey: areaId, status: response.status),
        hasMore: false,
      );
    }
    throw InkeFailure(InkeFailureKind.invalidArgument, 'area "$areaId" is not an Inke showcase');
  }

  /// The app's hot list (the recommendations and the directory): one page. A
  /// page after the first is empty, without a request; a page below 1 is a
  /// caller error.
  Future<({List<LiveRoom> rooms, bool hasMore})> hot({int page = 1}) async {
    if (page < 1) throw InkeFailure(InkeFailureKind.invalidArgument, 'page $page is below 1');
    if (page > 1) return (rooms: const <LiveRoom>[], hasMore: false);
    final response = await http.get(InkeEndpoints.hotUrl);
    return (rooms: InkeRoomParser.hotPage(response.text, status: response.status), hasMore: false);
  }

  // Search --------------------------------------------------------------------

  /// Rooms for [keyword]:
  /// - a page or page size below 1 is a caller error;
  /// - a uid or Inke room link finds that room on page 1 only, or nothing
  ///   when the site answers not-found (an offline room has no name);
  /// - another link (a URL with a scheme and host) or a blank keyword finds
  ///   nothing, without a request;
  /// - anything else filters the nicknames of the top list, the channels and
  ///   the app's hot list (see [InkeRoomParser.searchShowcases]). The hot
  ///   list failing leaves its rooms out. A page over 10000, a page size
  ///   over 60 or a keyword over 100 characters is refused without a
  ///   request, as the reference refused them.
  Future<({List<LiveRoom> rooms, bool? hasMore})> search(String keyword, {int page = 1, int pageSize = 30}) async {
    if (page < 1) throw InkeFailure(InkeFailureKind.invalidArgument, 'page $page is below 1');
    if (pageSize < 1) throw InkeFailure(InkeFailureKind.invalidArgument, 'page size $pageSize is below 1');
    final input = keyword.trim();
    final uid = _exactRoom(input);
    if (uid != null) {
      if (page != 1) return (rooms: const <LiveRoom>[], hasMore: null);
      try {
        return (rooms: [await detail(uid)], hasMore: null);
      } on InkeFailure catch (failure) {
        if (failure.kind != InkeFailureKind.notFound) rethrow;
        return (rooms: const <LiveRoom>[], hasMore: null);
      }
    }
    if (_isLink(input)) return (rooms: const <LiveRoom>[], hasMore: null);
    if (page > InkeEndpoints.maxSearchPage) {
      throw InkeFailure(InkeFailureKind.invalidArgument, 'page $page is past ${InkeEndpoints.maxSearchPage}');
    }
    if (pageSize > InkeEndpoints.maxSearchSize) {
      throw InkeFailure(InkeFailureKind.invalidArgument, 'page size $pageSize is past ${InkeEndpoints.maxSearchSize}');
    }
    if (input.toLowerCase().length > InkeEndpoints.maxKeywordLength) {
      throw const InkeFailure(InkeFailureKind.invalidArgument, 'keyword is past 100 characters');
    }
    if (input.isEmpty) return (rooms: const <LiveRoom>[], hasMore: null);
    final top = await http.get(InkeEndpoints.topUrl);
    final showcase = InkeRoomParser.topPage(top.text, status: top.status);
    final channels = await http.get(InkeEndpoints.channelsUrl);
    final channelRooms = InkeRoomParser.channelRooms(channels.text, status: channels.status);
    List<LiveRoom> hot;
    try {
      final response = await http.get(InkeEndpoints.hotUrl);
      hot = InkeRoomParser.hotPage(response.text, status: response.status);
    } on InkeFailure {
      hot = const <LiveRoom>[];
    }
    return InkeRoomParser.searchShowcases(
      input,
      [...showcase, ...channelRooms],
      hot: hot,
      page: page,
      pageSize: pageSize,
    );
  }

  /// The room [input] names exactly: a uid, or a room link.
  static String? _exactRoom(String input) =>
      InkeEndpoints.isId(input) ? input : InkeEndpoints.roomIdFromUri(Uri.tryParse(input));

  /// Whether [input] is a link (`scheme://…`) rather than a keyword. The
  /// reference took any text with a scheme for one, so keywords such as
  /// `Re:Zero` find nothing.
  static bool _isLink(String input) {
    final uri = Uri.tryParse(input);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  // Rooms ---------------------------------------------------------------------

  /// Room entry: `live_share_pc`, and `now_publish` when the website says
  /// the room is live (the app's title, cover, audience and start time; its
  /// answer is kept as the room's stream handle and serves the first play).
  /// The app failing, or saying the anchor is not live, leaves the room as
  /// the website gave it (the stream request reports it). An id that is not
  /// a uid is not-found without a request; a room the website calls offline
  /// is remembered as such (one request, and its streams say so without
  /// another).
  Future<LiveRoom> detail(String roomId) async {
    final uid = _uid(roomId);
    final response = await http.get(InkeEndpoints.shareUrl(uid));
    final room = InkeRoomParser.detail(response.text, uid: uid, status: response.status);
    final handle = room.runtime.streamHandle;
    if (handle is! InkeRoomData) {
      _remember(uid, const InkeRoomData(liveId: null));
      return room;
    }
    try {
      final (broadcast, at) = await _broadcast(uid);
      if (broadcast == null) {
        _remember(uid, handle);
        return room;
      }
      final entered = InkeRoomData(liveId: broadcast.liveId, broadcast: broadcast, receivedAt: at);
      _remember(uid, entered);
      return InkeRoomParser.withBroadcast(room, broadcast, receivedAt: at, data: entered);
    } on InkeFailure {
      _remember(uid, handle);
      return room;
    }
  }

  /// A refresh: the share page's room, without the broadcast a first visit
  /// resolves for playback and danmaku.
  Future<LiveRoom> refreshRoom(String roomId) async {
    final uid = _uid(roomId);
    final response = await http.get(InkeEndpoints.shareUrl(uid));
    return InkeRoomParser.detail(response.text, uid: uid, status: response.status);
  }

  /// `now_publish` for [uid] and when it was received.
  Future<(InkeBroadcast?, DateTime)> _broadcast(String uid) async {
    final response = await http.get(InkeEndpoints.publishUrl(uid));
    final at = _now();
    return (InkeRoomParser.broadcast(response.text, uid: uid, status: response.status), at);
  }

  /// [roomId] as a uid; anything else is not-found without a request.
  String _uid(String roomId) {
    final id = roomId.trim();
    if (!InkeEndpoints.isId(id)) throw InkeFailure(InkeFailureKind.notFound, 'not a uid: $id');
    return id;
  }

  /// Keeps [data] as the stream data of [uid], dropping the oldest past
  /// [_streamLimit].
  void _remember(String uid, InkeRoomData data) {
    _streams
      ..remove(uid)
      ..[uid] = data;
    while (_streams.length > _streamLimit) {
      _streams.remove(_streams.keys.first);
    }
  }

  // Streams -------------------------------------------------------------------

  /// The stream data of [roomId]: the one its room entry brought, or a fresh
  /// entry — the capabilities are asked by room id alone.
  Future<InkeRoomData> _stream(String roomId) async {
    final uid = _uid(roomId);
    final data = _streams[uid];
    if (data != null) return data;
    await detail(uid);
    return _streams[uid]!;
  }

  /// The qualities [roomId] offers, without more than the room entry: 3.x's
  /// FLV (H.264), and the original (HEVC) when the app answer has its line.
  /// A room the platform called offline says so.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async {
    final data = await _stream(roomId);
    return InkeRoomParser.qualities(data, preferH264: _preferH264());
  }

  /// The lines of [quality] for [roomId], with the media headers and their
  /// leases. A null [quality] takes the display's first: the original when
  /// "prefer H.264" is off and the room has its Zego line, else the FLV. A
  /// room the platform called offline says so, without a request.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async {
    final data = await _stream(roomId);
    if (data.liveId == null && data.broadcast == null) {
      throw const InkeFailure(InkeFailureKind.streamUnavailable, 'the room is not live');
    }
    final requested = quality?.qualityId?.trim();
    final hasOrigin = data.broadcast?.originUrl != null;
    final id = switch (requested) {
      null => _preferH264() || !hasOrigin ? InkeEndpoints.flvQualityId : InkeEndpoints.originQualityId,
      final String given => given,
    };
    return await _resolve(_uid(roomId), id, data, reuse: true);
  }

  /// The lines of [qualityId] for [uid]'s anchor:
  /// 1. The app's broadcast: the room entry's when [reuse] and it is younger
  ///    than [answerReuse], else `now_publish`. When the app says the anchor
  ///    is not live, that is stream-unavailable and nothing else is asked.
  /// 2. The original ([InkeEndpoints.originQualityId]): its Zego line; none
  ///    is stream-unavailable, and the app failing is reported.
  /// 3. The FLV ([InkeEndpoints.flvQualityId]): its Wangsu line; when the app
  ///    gave none, or failed, the showcases in [InkeEndpoints.showcasePaths]
  ///    order are looked through for the broadcast the app named or else the
  ///    room entry's, until one holds it. The app's failure is reported when
  ///    none does; without either broadcast id it is reported at once.
  Future<List<LivePlayLine>> _resolve(String uid, String qualityId, InkeRoomData data, {required bool reuse}) async {
    final original = qualityId == InkeEndpoints.originQualityId;
    if (!original && qualityId != InkeEndpoints.flvQualityId) {
      throw InkeFailure(InkeFailureKind.streamUnavailable, 'quality $qualityId is not offered');
    }
    InkeBroadcast? broadcast;
    var issuedAt = _now();
    InkeFailure? appFailure;
    final known = data.broadcast;
    final knownAt = data.receivedAt;
    final age = knownAt == null ? null : issuedAt.difference(knownAt);
    if (reuse && known != null && age != null && !age.isNegative && age < answerReuse) {
      broadcast = known;
      issuedAt = knownAt!;
    } else {
      try {
        final (answer, at) = await _broadcast(uid);
        if (answer == null) throw InkeFailure(InkeFailureKind.streamUnavailable, '$uid is not live');
        broadcast = answer;
        issuedAt = at;
      } on InkeFailure catch (failure) {
        if (failure.kind == InkeFailureKind.streamUnavailable) rethrow;
        if (original) rethrow;
        appFailure = failure;
      }
    }
    if (original) {
      final url = broadcast!.originUrl;
      if (url == null) {
        throw InkeFailure(InkeFailureKind.streamUnavailable, '$uid: no original (Zego) line');
      }
      return [InkeRoomParser.zegoLine(url, issuedAt: issuedAt)];
    }
    if (broadcast?.pullUrl case final url?) {
      return [InkeRoomParser.flvLine(url, issuedAt: issuedAt)];
    }
    final liveId = broadcast?.liveId ?? data.liveId;
    if (liveId == null) {
      throw appFailure ?? InkeFailure(InkeFailureKind.streamUnavailable, '$uid: no pull URL');
    }
    for (final path in InkeEndpoints.showcasePaths) {
      final response = await http.get(InkeEndpoints.showcaseUrl(path));
      final urls = InkeRoomParser.showcaseUrls(
        response.text,
        path: path,
        uid: uid,
        liveId: liveId,
        status: response.status,
      );
      if (urls.isNotEmpty) {
        return [for (final url in urls) InkeRoomParser.flvLine(url, issuedAt: _now())];
      }
    }
    throw appFailure ?? InkeFailure(InkeFailureKind.streamUnavailable, '$uid: no pull URL for broadcast $liveId');
  }

  // Links ---------------------------------------------------------------------

  /// The canonical room page of an Inke room or app share link: the web
  /// page, keeping a single numeric broadcast id when the link carries one.
  /// Null when the link names no room.
  Uri? canonicalRoomUrl(Uri uri) {
    final uid = InkeEndpoints.roomIdFromUri(uri);
    if (uid == null) return null;
    return InkeEndpoints.canonicalRoomUrl(uri, uid);
  }

  // Capability wiring ---------------------------------------------------------

  InkeRoomProvider? _room;
  InkeAreaProvider? _area;
  InkeDiscoveryProvider? _discovery;
  InkeSearchProvider? _search;
  InkePlaybackProvider? _playback;
  InkeLinkResolver? _link;
  InkeRoomRefresh? _refresh;
  InkeStatusCheck? _status;
  InkePlayLeaseLookup? _lease;

  /// The capability of type [T], or null when Inke does not support it
  /// (ARCHITECTURE.md §4.1) — the platform has no chat, so no
  /// `LiveDanmakuProvider` exists here. Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= InkeRoomProvider(site: this);
    final area = _area ??= InkeAreaProvider(site: this);
    final discovery = _discovery ??= InkeDiscoveryProvider(site: this);
    final search = _search ??= InkeSearchProvider(site: this);
    final playback = _playback ??= InkePlaybackProvider(site: this);
    final link = _link ??= InkeLinkResolver(site: this);
    final refresh = _refresh ??= InkeRoomRefresh(site: this);
    final status = _status ??= InkeStatusCheck(refresh: refresh);
    final lease = _lease ??= InkePlayLeaseLookup(now: _now);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => area as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LiveLinkResolver) => link as T,
      const (LiveRoomRefresh) => refresh as T,
      const (LiveStatusCheck) => status as T,
      const (LivePlayLeaseLookup) => lease as T,
      _ => null,
    };
  }
}
