import 'dart:async';

// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'package:live_net/live_net.dart' show CancelToken;
import 'package:live_sites/src/capabilities/live_area_provider.dart';
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
import 'package:live_sites/src/platforms/cc/api/cc_endpoints.dart';
import 'package:live_sites/src/platforms/cc/api/cc_http.dart';
import 'package:live_sites/src/platforms/cc/capabilities/cc_area_provider.dart';
import 'package:live_sites/src/platforms/cc/capabilities/cc_discovery_provider.dart';
import 'package:live_sites/src/platforms/cc/capabilities/cc_link_resolver.dart';
import 'package:live_sites/src/platforms/cc/capabilities/cc_playback_provider.dart';
import 'package:live_sites/src/platforms/cc/capabilities/cc_room_provider.dart';
import 'package:live_sites/src/platforms/cc/capabilities/cc_room_refresh.dart';
import 'package:live_sites/src/platforms/cc/capabilities/cc_search_provider.dart';
import 'package:live_sites/src/platforms/cc/capabilities/cc_status_check.dart';
import 'package:live_sites/src/platforms/cc/cc_manifest.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_catalog_parser.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_json.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_play_parser.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One page of a room list: its rooms and whether a full page means more
/// may follow.
typedef CcListing = ({List<LiveRoom> rooms, bool hasMore});

/// The NetEase CC adapter (3.x's `CCSite`; parsing in `parsers/`): manifest
/// + capability discovery + lifecycle (ARCHITECTURE.md §7.2).
///
/// Every request is anonymous: 3.x had no CC account or cookie, and CC has
/// no danmaku (3.x neither), so there is no danmaku capability. Lists,
/// search and room details are 3.x's: the category feeds, `activitylives`
/// then `live/channel`. Where 3.x had nothing the fixes step in: an anchor
/// without a live channel is offline (room entry reads its room page, a
/// follow refresh asks whether the id exists, 9-7). With the approved
/// upgrades the catalog is the mobile site's (with 3.x's official entries
/// from the Dashen configuration, 9-4) and the qualities are
/// `video_play_url`'s real tiers (9-1), 3.x's stream list being the
/// fallback. Failures are [CcFailure]s; nothing is disguised as an offline
/// room.
final class CcSite implements LiveSite {
  /// Creates the adapter over [http]. [now] (the leases' issue time and the
  /// qualities answer's age) is injectable for tests.
  CcSite({required this.http, DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// How long the `video_play_url` answer that listed a room's qualities
  /// stands in for the request of its own tier (the first play after
  /// entering a room), once. Its URLs admit new connections for 300 s.
  static const Duration qualityAnswerReuse = Duration(seconds: 30);

  /// The limit of a follow refresh's existence check (9-7); past it the
  /// anchor stays marked offline.
  static const Duration existenceTimeout = CcEndpoints.existenceTimeout;

  /// Transport.
  final CcHttp http;

  final DateTime Function() _now;

  /// The last qualities answer of each room, until its tier is played,
  /// oldest first.
  final Map<String, CcPlayAnswer> _qualityAnswers = {};

  /// The rooms whose qualities last came from the 3.x fallback: their
  /// quality ids are stream-list tier codes, played from the room's own
  /// data without a request. (The reference tells the two apart on the
  /// quality's payload; the shared quality model carries none, so the site
  /// remembers which answer produced the list.)
  final Map<String, CcRoomData> _legacyQualities = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => ccManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Catalog -------------------------------------------------------------------

  /// The catalog (9-4): the mobile site's areas, grouped by their category
  /// (`wapcc/gamecategory?catetype=0` names the categories, then one
  /// request per category lists its areas, together; any of them failing
  /// fails the catalog, 3.x's all-or-nothing; categories without areas are
  /// left out), then 3.x's official rooms and events from the Dashen
  /// registry and configuration beside them, when they can be read —
  /// without them the catalog is still shown.
  Future<List<LiveArea>> catalog() async {
    final [categories, official] = await Future.wait<List<Object>>([_mobileAreas(), _officialAreas()]);
    return [...categories.cast<LiveArea>(), ...official.cast<LiveArea>()];
  }

  Future<List<LiveArea>> _mobileAreas() async {
    final all = await http.get(CcEndpoints.categoryUrl('0'));
    final types = CcCatalogParser.categoryTypes(all.text, status: all.status);
    final answers = await Future.wait([for (final category in types) http.get(CcEndpoints.categoryUrl(category.id))]);
    return [
      for (final (index, (:id, :name)) in types.indexed)
        ...CcCatalogParser.categoryAreas(answers[index].text, id: id, name: name, status: answers[index].status),
    ];
  }

  /// 3.x's official entries, or none when the Dashen requests fail or their
  /// answers cannot be read.
  Future<List<LiveArea>> _officialAreas() async {
    try {
      final (games, config) = (
        await http.get(CcEndpoints.dashenGamesUrl(), headers: CcEndpoints.dashenHeaders),
        await http.postJson(CcEndpoints.dashenConfigUrl(), {'id': CcEndpoints.catalogConfigurationId}),
      );
      return CcCatalogParser.officialAreas(
        games.text,
        config.text,
        gamesStatus: games.status,
        configStatus: config.status,
      );
    } on CcFailure {
      return const [];
    }
  }

  // Lists ---------------------------------------------------------------------

  /// Rooms of a live area: `start` = (page − 1) × [pageSize], a full page
  /// meaning more may follow. An official entry, another platform's area or
  /// a page out of 1–100000 × 1–1000 is a caller error and sends nothing,
  /// as in 3.x.
  Future<CcListing> areaRooms(LiveArea area, {int page = 1, int pageSize = 30, CancelToken? cancel}) async {
    if (!CcCatalogParser.isListableArea(area) || page < 1 || page > 100000 || pageSize < 1 || pageSize > 1000) {
      throw const CcFailure(CcFailureKind.invalidArgument, 'Invalid CC category or pagination');
    }
    final game = area.areaId.trim();
    final response = await http.get(
      CcEndpoints.areaRoomsUrl(game, start: (page - 1) * pageSize, size: pageSize),
      cancel: cancel,
    );
    final rooms = CcRoomParser.areaRooms(response.text, gametype: game, status: response.status);
    return (rooms: rooms, hasMore: rooms.length == pageSize);
  }

  /// Every live room, [pageSize] a page (the popular page asks for 100); a
  /// page or size below 1 is asked as 1, as the reference sends it. A full
  /// page means more may follow.
  Future<CcListing> recommend({int page = 1, int pageSize = 30}) async {
    final size = pageSize < 1 ? 1 : pageSize;
    final safePage = page < 1 ? 1 : page;
    final response = await http.get(CcEndpoints.recommendUrl(start: (safePage - 1) * size, size: size));
    final rooms = CcRoomParser.recommendRooms(response.text, status: response.status);
    return (rooms: rooms, hasMore: rooms.length == size);
  }

  /// Streamers matching [keyword], live or not; [pageSize] is sent, limited
  /// to 1–50, a page below 1 as 1. A blank keyword gives nothing without a
  /// request. The search answers pages natively, so whether more follow is
  /// its own answer (unknown here).
  Future<List<LiveRoom>> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final text = keyword.trim();
    if (text.isEmpty) return const [];
    final response = await http.get(
      CcEndpoints.searchUrl(text, page: page < 1 ? 1 : page, size: pageSize.clamp(1, 50)),
    );
    return CcRoomParser.searchRooms(response.text, status: response.status);
  }

  // Rooms ---------------------------------------------------------------------

  /// The room of [roomId], as the user asked for it (3.x's two requests):
  /// 1. `activitylives` gives the channel the anchor broadcasts in;
  /// 2. with one, `live/channel` gives the live room.
  ///
  /// Without a channel (or when it ended in between) the anchor is not
  /// broadcasting; 3.x failed there. On room entry the room page fills the
  /// room and tells an unknown id (not-found). A follow refresh of an
  /// anchor without a channel asks [_anchorExists] (9-7); recordings and
  /// status checks only mark the room offline. A non-numeric id is
  /// not-found without a request.
  Future<LiveRoom> _detail(String roomId, {required CcDetailDepth depth}) async {
    final ccid = roomId.trim();
    if (!CcEndpoints.ccidPattern.hasMatch(ccid)) {
      throw CcFailure(CcFailureKind.notFound, 'room id $ccid is not a ccid');
    }
    final lives = await http.get(CcEndpoints.anchorLivesUrl(ccid));
    final channel = CcRoomParser.liveChannel(lives.text, ccid: ccid, status: lives.status);
    if (channel != null) {
      final response = await http.get(CcEndpoints.channelUrl(channel));
      final room = CcRoomParser.channelRoom(response.text, ccid: ccid, status: response.status);
      if (room != null) return room;
    }
    if (depth == CcDetailDepth.entry) {
      final page = await http.get(CcEndpoints.roomPageUrl(ccid));
      return CcRoomParser.pageRoom(page.text, ccid: ccid, status: page.status);
    }
    // A channel that ended in between belongs to an existing anchor.
    if (depth == CcDetailDepth.refresh && channel == null && !await _anchorExists(ccid)) {
      throw CcFailure(CcFailureKind.notFound, 'no CC account $ccid');
    }
    return CcRoomParser.offlineRoom(ccid);
  }

  /// Room entry (3.x's two requests, plus the room page when the anchor has
  /// no live channel).
  Future<LiveRoom> detail(String roomId) => _detail(roomId, depth: CcDetailDepth.entry);

  /// Follow-card refresh: 3.x's requests. An anchor without a live channel
  /// is offline, the stored card keeping everything else, unless CC says
  /// the id is no account: not-found (9-7, one request more).
  Future<LiveRoom> refreshRoom(String roomId) => _detail(roomId, depth: CcDetailDepth.refresh);

  /// A room on air carries its tier list; anything else is offline, read no
  /// further (recordings and status checks).
  Future<LiveRoom> statusRoom(String roomId) => _detail(roomId, depth: CcDetailDepth.status);

  /// Whether [ccid] is an account (9-7): one small request
  /// ([CcRoomParser.anchorExists]; about 2.5 KB, 81 bytes for an unknown
  /// id, where the room page is about 110 KB). Only the platform's "no such
  /// ccid" is false: a failed, slow or unreadable answer leaves the anchor
  /// marked offline, as before. A cancellation propagates.
  Future<bool> _anchorExists(String ccid) async {
    try {
      final response = await http.get(CcEndpoints.existsUrl(ccid), timeout: CcEndpoints.existenceTimeout);
      return CcRoomParser.anchorExists(response.text, status: response.status);
    } on CcFailure {
      return true;
    }
  }

  // Streams -------------------------------------------------------------------

  /// The room's real tiers from `video_play_url` (9-1): one request, whose
  /// answer also stands in for the first play of its selected tier (see
  /// [qualityAnswerReuse]). An anchor who is not broadcasting is
  /// stream-unavailable. When the answer fails otherwise or cannot be read
  /// and the room carries its tier list, 3.x's qualities are the fallback
  /// ([CcPlayParser.legacyQualities], no request).
  Future<List<LivePlayQuality>> qualitiesOf(LiveRoom room) async {
    final ccid = room.roomId.trim();
    try {
      final answer = await _play(ccid);
      final qualities = CcPlayParser.qualities(answer.data);
      _rememberQualityAnswer(ccid, answer);
      _legacyQualities.remove(ccid);
      return qualities;
    } on CcFailure catch (failure) {
      if (failure.kind == CcFailureKind.streamUnavailable) rethrow;
      if (room.runtime.streamHandle case final CcRoomData data) {
        final qualities = CcPlayParser.legacyQualities(data);
        if (qualities.isNotEmpty) {
          _rememberLegacyQualities(ccid, data);
          return qualities;
        }
      }
      rethrow;
    }
  }

  /// The lines of [quality]: a 3.x quality (the fallback) plays its own
  /// URLs, as 3.x did, without a request. A `video_play_url` quality gets
  /// fresh lines every time (a URL admits new connections for 300 seconds,
  /// so renewal and recovery ask again): the answer to `vbrname={code}`,
  /// then one request per CDN of `cdn_list` it left out, together; a
  /// failing CDN request leaves the other lines. Right after
  /// [qualitiesOf], its answer serves the tier it selected instead of the
  /// first request (once, within [qualityAnswerReuse]).
  Future<List<LivePlayLine>> linesOf(LiveRoom room, LivePlayQuality quality) async {
    final ccid = room.roomId.trim();
    final code = quality.qualityId;
    if (_legacyQualities[ccid] case final data?) {
      final lines = CcPlayParser.legacyLines(data, code ?? '', roomId: ccid);
      if (lines.isEmpty) {
        throw CcFailure(CcFailureKind.streamUnavailable, 'quality $code has no URL');
      }
      return lines;
    }
    final first = _takeQualityAnswer(ccid, code) ?? await _play(ccid, quality: code);
    final others = await Future.wait([
      for (final cdn in CcPlayParser.uncoveredCdns(first.data)) _otherCdn(ccid, quality: code, cdn: cdn),
    ]);
    return CcPlayParser.lines([first, ...others.nonNulls], roomId: ccid);
  }

  /// The qualities answer of [roomId], taken (every call drops it), when it
  /// is recent and selected [code].
  CcPlayAnswer? _takeQualityAnswer(String roomId, String? code) {
    final answer = _qualityAnswers.remove(roomId.trim());
    if (answer == null || code == null || CcJson.string(answer.data['vbrname_sel']) != code) return null;
    final age = _now().difference(answer.issuedAt);
    return age.isNegative || age > qualityAnswerReuse ? null : answer;
  }

  /// Keeps [answer] as the latest of its room, dropping the oldest past 8.
  void _rememberQualityAnswer(String roomId, CcPlayAnswer answer) {
    _qualityAnswers
      ..remove(roomId)
      ..[roomId] = answer;
    if (_qualityAnswers.length > 8) _qualityAnswers.remove(_qualityAnswers.keys.first);
  }

  /// Keeps [data] as the legacy tier list of [roomId], dropping the oldest
  /// past 8.
  void _rememberLegacyQualities(String roomId, CcRoomData data) {
    _legacyQualities
      ..remove(roomId)
      ..[roomId] = data;
    if (_legacyQualities.length > 8) _legacyQualities.remove(_legacyQualities.keys.first);
  }

  Future<CcPlayAnswer?> _otherCdn(String roomId, {required String? quality, required String cdn}) async {
    try {
      return await _play(roomId, quality: quality, cdn: cdn);
    } on CcFailure {
      return null;
    }
  }

  /// `vapi.cc.163.com/video_play_url/{ccid}` as the website's h5 player
  /// asks for it, at [quality] and [cdn] when given.
  Future<CcPlayAnswer> _play(String roomId, {String? quality, String? cdn}) async {
    final ccid = roomId.trim();
    if (!CcEndpoints.ccidPattern.hasMatch(ccid)) {
      throw CcFailure(CcFailureKind.streamUnavailable, 'room id $ccid is not a ccid');
    }
    final response = await http.get(CcEndpoints.playUrl(ccid, quality: quality, cdn: cdn));
    return (data: CcPlayParser.playData(response.text, status: response.status), issuedAt: _now());
  }

  // Capability wiring ---------------------------------------------------------

  CcRoomProvider? _room;
  CcAreaProvider? _area;
  CcDiscoveryProvider? _discovery;
  CcSearchProvider? _search;
  CcPlaybackProvider? _playback;
  CcLinkResolver? _link;
  CcRoomRefresh? _refresh;
  CcStatusCheck? _status;

  /// The capability of type [T], or null when CC does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site. CC has
  /// no danmaku and no gifts (3.x neither), so there is no danmaku
  /// capability to find.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= CcRoomProvider(site: this);
    final area = _area ??= CcAreaProvider(site: this);
    final discovery = _discovery ??= CcDiscoveryProvider(site: this);
    final search = _search ??= CcSearchProvider(site: this);
    final playback = _playback ??= CcPlaybackProvider(site: this);
    final link = _link ??= CcLinkResolver(site: this);
    final refresh = _refresh ??= CcRoomRefresh(site: this);
    final status = _status ??= CcStatusCheck(refresh: refresh);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => area as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LiveLinkResolver) => link as T,
      const (LiveRoomRefresh) => refresh as T,
      const (LiveStatusCheck) => status as T,
      _ => null,
    };
  }
}
