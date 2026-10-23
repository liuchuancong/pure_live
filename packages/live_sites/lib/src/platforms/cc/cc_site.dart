// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'package:live_sites/src/capabilities/live_area_provider.dart';
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
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/cc/api/cc_endpoints.dart';
import 'package:live_sites/src/platforms/cc/api/cc_http.dart';
import 'package:live_sites/src/platforms/cc/capabilities/cc_area_provider.dart';
import 'package:live_sites/src/platforms/cc/capabilities/cc_discovery_provider.dart';
import 'package:live_sites/src/platforms/cc/capabilities/cc_link_resolver.dart';
import 'package:live_sites/src/platforms/cc/capabilities/cc_playback_provider.dart';
import 'package:live_sites/src/platforms/cc/capabilities/cc_room_provider.dart';
import 'package:live_sites/src/platforms/cc/capabilities/cc_search_provider.dart';
import 'package:live_sites/src/platforms/cc/cc_manifest.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_json.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How many entered rooms keep their stream data.
const _roomLimit = 64;

/// How many rooms keep their qualities answer for its first line request.
const _answerLimit = 8;

/// The NetEase CC adapter (3.x's `CCSite`; parsing in `parsers/`): manifest +
/// capability discovery + lifecycle (ARCHITECTURE.md §7.2).
///
/// Every request is anonymous: there is no CC account or cookie. Lists,
/// search and room details are the website's: the category feeds,
/// `activitylives` then `live/channel`; an anchor without a live channel is
/// offline, and room entry reads its room page, which also tells an unknown
/// id. The catalog is the mobile site's, with 3.x's "官方房间/专题" entries
/// from the Dashen registry and configuration beside it; their failure does
/// not fail the catalog. The qualities are `video_play_url`'s real tiers,
/// 3.x's redirect playlist being the fallback when the room carries its tier
/// list. CC has no danmaku (3.x neither), so no danmaku capability exists.
/// Failures are [CcFailure]s; nothing is disguised as an offline room.
final class CcSite implements LiveSite {
  /// Creates the adapter over [http]. [now] (the play answers' clock) is
  /// injectable for tests.
  CcSite({required this.http, DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Transport.
  final CcHttp http;

  final DateTime Function() _now;

  /// The stream data of the rooms entered, by ccid: the tier list a play
  /// fallback reads.
  final Map<String, CcRoomData> _rooms = {};

  /// The last qualities answer of each room, until its tier is played.
  final Map<String, _PlayAnswer> _qualityAnswers = {};

  /// The rooms whose last qualities came from their channel's tier list (the
  /// fallback), whose lines then need no request.
  final Set<String> _legacy = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => ccManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Catalog -------------------------------------------------------------------

  /// The mobile site's catalog: `gamecategory?catetype=0` names the
  /// categories (网游, 手游, 竞技, 综艺), then one request per category lists
  /// its areas, together; any of them failing fails the catalog (3.x's
  /// all-or-nothing; the areas carry their category in
  /// `parentAreaId`/`parentAreaName`). After them, 3.x's "官方房间/专题"
  /// from the Dashen registry and configuration, requested beside the first
  /// one, when they can be read; without them the catalog is still shown.
  Future<List<LiveArea>> areas() async {
    final [mobile, official] = await Future.wait([_mobileAreas(), _officialAreas()]);
    return [...mobile, ...official];
  }

  Future<List<LiveArea>> _mobileAreas() async {
    final all = await http.get(CcEndpoints.categoryTypesUrl());
    final types = CcRoomParser.categoryTypes(all.text, status: all.status);
    final answers = await Future.wait([
      for (final category in types) http.get(CcEndpoints.categoryAreasUrl(category.id)),
    ]);
    return [
      for (final (index, (:id, :name)) in types.indexed)
        ...CcRoomParser.categoryAreas(answers[index].text, id: id, name: name, status: answers[index].status),
    ];
  }

  /// 3.x's official entries ([CcRoomParser.officialAreas]), or none when the
  /// Dashen requests fail or their answers cannot be read.
  Future<List<LiveArea>> _officialAreas() async {
    try {
      final [games, config] = await Future.wait([
        http.get(CcEndpoints.officialGamesUrl(), headers: CcEndpoints.dashenHeaders),
        http.postJson(CcEndpoints.officialConfigUrl(), {
          'id': CcEndpoints.catalogConfigurationId,
        }, headers: CcEndpoints.dashenHeaders),
      ]);
      return CcRoomParser.officialAreas(
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

  /// Rooms of the live area [areaId]: `start` = (page − 1) × [pageSize], a
  /// page out of 1–100000 or a page size out of 1–1000 kept from outrunning
  /// the platform's own limits. An official entry (not a game type) is a
  /// caller error and sends nothing, as in 3.x. A full page may have more.
  Future<({List<LiveRoom> rooms, bool hasMore})> areaRooms(String areaId, {int page = 1, int pageSize = 30}) async {
    final game = areaId.trim();
    if (!CcEndpoints.isAreaId(game) ||
        page < 1 ||
        page > CcEndpoints.maxPage ||
        pageSize < 1 ||
        pageSize > CcEndpoints.maxPageSize) {
      throw CcFailure(
        CcFailureKind.invalidArgument,
        'area "$areaId" is not a CC game type or the pagination is out of range',
      );
    }
    final response = await http.get(CcEndpoints.categoryRoomsUrl(game, start: (page - 1) * pageSize, size: pageSize));
    final rooms = CcRoomParser.categoryRooms(response.text, gametype: game, status: response.status);
    return (rooms: rooms, hasMore: rooms.length == pageSize);
  }

  /// Every live room, [pageSize] a page (clamped to the platform's row
  /// limit; the popular page asks for 100). A full page may have more.
  Future<({List<LiveRoom> rooms, bool hasMore})> recommend({int page = 1, int pageSize = 30}) async {
    final size = pageSize.clamp(1, CcEndpoints.maxPageSize);
    final current = page < 1 ? 1 : page;
    final response = await http.get(CcEndpoints.recommendRoomsUrl(start: (current - 1) * size, size: size));
    final rooms = CcRoomParser.recommendRooms(response.text, status: response.status);
    return (rooms: rooms, hasMore: rooms.length == size);
  }

  // Search --------------------------------------------------------------------

  /// Streamers matching [keyword], live or not (3.x's anchor search);
  /// [pageSize] is sent, limited to 1–50. The path ends with a slash (without
  /// it the site answers 301). A blank keyword gives nothing without a
  /// request. The search answer says nothing about pages.
  Future<({List<LiveRoom> rooms, bool? hasMore})> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final text = keyword.trim();
    if (text.isEmpty) return (rooms: const <LiveRoom>[], hasMore: null);
    final response = await http.get(
      CcEndpoints.searchUrl(text, page: page < 1 ? 1 : page, size: pageSize.clamp(1, CcEndpoints.maxSearchSize)),
    );
    return (rooms: CcRoomParser.searchRooms(response.text, status: response.status), hasMore: null);
  }

  // Rooms ---------------------------------------------------------------------

  /// The room of [roomId], as the user asked for it (3.x's two requests):
  /// 1. `activitylives` gives the channel the anchor broadcasts in;
  /// 2. with one, `live/channel` gives the live room, with its tier list.
  ///
  /// Without a channel (or when it ended in between) the anchor is not
  /// broadcasting; 3.x failed there. On room entry the room page fills the
  /// room and tells an unknown id (`not-found`). A non-numeric id is
  /// not-found without a request.
  Future<LiveRoom> detail(String roomId) async {
    final ccid = roomId.trim();
    if (!CcEndpoints.isCcid(ccid)) {
      throw CcFailure(CcFailureKind.notFound, 'room id $ccid is not a ccid');
    }
    final lives = await http.get(CcEndpoints.liveChannelsUrl(ccid));
    final channel = CcRoomParser.liveChannel(lives.text, ccid: ccid, status: lives.status);
    if (channel != null) {
      final response = await http.get(CcEndpoints.channelUrl(channel));
      final answer = CcRoomParser.channelRoom(response.text, ccid: ccid, status: response.status);
      if (answer != null) {
        _remember(ccid, answer.data);
        _legacy.remove(ccid);
        return answer.room.rebuild((b) => b..runtime = RoomRuntime.of(streamHandle: answer.data).toBuilder());
      }
    }
    // A channel that ended in between belongs to an existing anchor: its
    // room page fills the room, and an unknown id is told apart there.
    final page = await http.get(CcEndpoints.roomPageUri(ccid));
    _rooms.remove(ccid);
    _legacy.remove(ccid);
    return CcRoomParser.pageRoom(page.text, ccid: ccid, status: page.status);
  }

  /// Keeps [data] as the latest of its room, dropping the oldest past
  /// [_roomLimit].
  void _remember(String ccid, CcRoomData data) {
    _rooms
      ..remove(ccid)
      ..[ccid] = data;
    while (_rooms.length > _roomLimit) {
      _rooms.remove(_rooms.keys.first);
    }
  }

  // Streams -------------------------------------------------------------------

  /// The room's real tiers from `video_play_url`: one request, whose answer
  /// also stands in for the first play of its selected tier (see
  /// [CcEndpoints.qualityAnswerReuse]). An anchor who is not broadcasting is
  /// stream-unavailable. When the answer fails otherwise or cannot be read
  /// and the room carries its tier list, 3.x's qualities are the fallback
  /// ([CcRoomParser.legacyQualities], no request).
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async {
    final ccid = roomId.trim();
    try {
      final answer = await _play(ccid);
      final qualities = CcRoomParser.qualities(answer.data);
      _qualityAnswers
        ..remove(ccid)
        ..[ccid] = answer;
      while (_qualityAnswers.length > _answerLimit) {
        _qualityAnswers.remove(_qualityAnswers.keys.first);
      }
      _legacy.remove(ccid);
      return qualities;
    } on CcFailure catch (failure) {
      if (failure.kind == CcFailureKind.streamUnavailable) rethrow;
      final data = _rooms[ccid];
      if (data != null) {
        final qualities = CcRoomParser.legacyQualities(data);
        if (qualities.isNotEmpty) {
          _legacy.add(ccid);
          return qualities;
        }
      }
      rethrow;
    }
  }

  /// A `video_play_url` quality gets fresh lines every time (a URL admits
  /// new connections for 300 seconds, so renewal and recovery ask again):
  /// the answer to `vbrname={code}`, then one request per CDN of `cdn_list`
  /// it left out, together; a failing CDN request leaves the other lines.
  /// Right after [qualitiesOf], its answer serves the tier it selected
  /// instead of the first request (once, within
  /// [CcEndpoints.qualityAnswerReuse]).
  ///
  /// A 3.x quality (the fallback) plays its own URLs, as 3.x did, without a
  /// request.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async {
    final ccid = roomId.trim();
    final code = quality?.qualityId?.trim();
    if (_legacy.contains(ccid)) {
      final data = _rooms[ccid];
      if (data != null) return CcRoomParser.legacyLines(data, code, roomId: ccid);
    }
    final first = _takeQualityAnswer(ccid, code) ?? await _play(ccid, quality: code);
    final others = await Future.wait([
      for (final cdn in CcRoomParser.uncoveredCdns(first.data)) _otherCdn(ccid, quality: code, cdn: cdn),
    ]);
    return CcRoomParser.resolution([first, ...others.nonNulls], roomId: ccid);
  }

  /// The qualities answer of [roomId], taken (every call drops it), when it
  /// is recent and selected [code].
  _PlayAnswer? _takeQualityAnswer(String roomId, String? code) {
    final answer = _qualityAnswers.remove(roomId);
    if (answer == null || code == null || CcJson.string(answer.data['vbrname_sel']) != code) return null;
    final age = _now().difference(answer.issuedAt);
    return age.isNegative || age > CcEndpoints.qualityAnswerReuse ? null : answer;
  }

  Future<_PlayAnswer?> _otherCdn(String roomId, {required String? quality, required String cdn}) async {
    try {
      return await _play(roomId, quality: quality, cdn: cdn);
    } on CcFailure {
      return null;
    }
  }

  /// `vapi.cc.163.com/video_play_url/{ccid}` as the website's h5 player asks
  /// for it (https URLs), at [quality] and [cdn] when given.
  Future<_PlayAnswer> _play(String roomId, {String? quality, String? cdn}) async {
    final ccid = roomId.trim();
    if (!CcEndpoints.isCcid(ccid)) {
      throw CcFailure(CcFailureKind.streamUnavailable, 'room id $ccid is not a ccid');
    }
    final response = await http.get(CcEndpoints.playUrl(ccid, quality: quality, cdn: cdn));
    return (data: CcRoomParser.playData(response.text, status: response.status), issuedAt: _now());
  }

  // Capability wiring ---------------------------------------------------------

  CcRoomProvider? _room;
  CcAreaProvider? _area;
  CcDiscoveryProvider? _discovery;
  CcSearchProvider? _search;
  CcPlaybackProvider? _playback;
  CcLinkResolver? _link;

  /// The capability of type [T], or null when CC does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site. CC has no
  /// danmaku (3.x neither): no danmaku capability exists.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= CcRoomProvider(site: this);
    final area = _area ??= CcAreaProvider(site: this);
    final discovery = _discovery ??= CcDiscoveryProvider(site: this);
    final search = _search ??= CcSearchProvider(site: this);
    final playback = _playback ??= CcPlaybackProvider(site: this);
    final link = _link ??= CcLinkResolver(site: this);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveAreaProvider) => area as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LiveLinkResolver) => link as T,
      _ => null,
    };
  }
}

/// A `video_play_url` answer and when it arrived (its leases count from
/// there).
typedef _PlayAnswer = ({Map<String, dynamic> data, DateTime issuedAt});
