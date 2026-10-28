import 'dart:async';

// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'package:live_net/live_net.dart';
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
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/chzzk/api/chzzk_endpoints.dart';
import 'package:live_sites/src/platforms/chzzk/api/chzzk_http.dart';
import 'package:live_sites/src/platforms/chzzk/capabilities/chzzk_area_provider.dart';
import 'package:live_sites/src/platforms/chzzk/capabilities/chzzk_discovery_provider.dart';
import 'package:live_sites/src/platforms/chzzk/capabilities/chzzk_link_resolver.dart';
import 'package:live_sites/src/platforms/chzzk/capabilities/chzzk_playback_provider.dart';
import 'package:live_sites/src/platforms/chzzk/capabilities/chzzk_room_provider.dart';
import 'package:live_sites/src/platforms/chzzk/capabilities/chzzk_room_refresh.dart';
import 'package:live_sites/src/platforms/chzzk/capabilities/chzzk_search_provider.dart';
import 'package:live_sites/src/platforms/chzzk/capabilities/chzzk_status_check.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_manifest.dart';
import 'package:live_sites/src/platforms/chzzk/danmaku/chzzk_danmaku_session.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_failure.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_json.dart' as json;
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_play_parser.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// A page of a lives list: its cards and the cursor of the next page.
typedef ChzzkListing = ({List<LiveRoom> rooms, bool hasMore, String? nextCursor});

/// The masters and variants one read of a channel's live produced, with when
/// they arrived: what the qualities and lines are handed out from while the
/// tokens still hold.
typedef ChzzkPlayback = ({List<ChzzkMedia> media, List<ChzzkVariant> variants, DateTime issuedAt});

/// The CHZZK adapter (parsing in `parsers/`): manifest + capability discovery +
/// lifecycle (ARCHITECTURE.md §7.2).
///
/// Anonymous, like the website's own player: no cookie, no account, no
/// signature. Every request carries [ChzzkEndpoints.headers] and follows no
/// redirect. The requests:
/// - the catalog is up to [ChzzkEndpoints.maxCategoryPages]
///   `categories/live` pages, each asked with the previous page's own
///   `page.next`; the areas come back flat, each carrying its `categoryType` as
///   its parent, and their types are remembered so a later area-page request
///   can name the path segment the platform needs;
/// - every browse (the site-wide list, an area's lives) is one `lives` page
///   after an opaque cursor; a caller that asks for a page *number* is walked
///   there from page 1 (that many requests) inside [directoryDeadline], because
///   the platform has no page parameter at all;
/// - a room is two requests, the channel and its `v3.1` live detail. A live
///   whose playback data cannot be read still stands as a room: the reason is
///   only reported when the stream is asked for;
/// - the stream has no address to keep: its masters are read on every quality
///   and line request while their Akamai tokens hold, and the room is entered
///   again once they do not (see [ChzzkSite.variantsOf]).
///
/// Rooms are identified by the channel id the platform writes (32 lower-case
/// hex digits); a live's `liveId` changes every broadcast and is never an
/// identity. Failures are [ChzzkFailure]s; nothing is disguised as an offline
/// room.
final class ChzzkSite implements LiveSite {
  /// Creates the adapter over [http]. [now] (when masters were issued, and
  /// whether their lines are due) and [directoryDeadline] (the budget of a
  /// page-number replay) are injectable for tests.
  ChzzkSite({required this.http, this.directoryDeadline = const Duration(seconds: 20), DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Transport.
  final ChzzkHttp http;

  /// Longest page-number replay.
  final Duration directoryDeadline;

  final DateTime Function() _now;

  /// The `categoryType` of every area id the catalog was read with, so an area
  /// page can be asked by its id alone.
  final Map<String, String> _areaTypes = {};

  /// The last masters and variants read per channel.
  final Map<String, ChzzkPlayback> _playback = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => chzzkManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Requests ------------------------------------------------------------------

  /// A GET with the platform's headers and the caller's cancellation.
  Future<ChzzkResponse> get(Uri url, {Map<String, String>? headers, CancelToken? cancel, Duration? timeout}) =>
      http.get(url, headers: headers, cancel: cancel, timeout: timeout);

  // Catalog -------------------------------------------------------------------

  /// The catalog: up to [ChzzkEndpoints.maxCategoryPages] `categories/live`
  /// pages, each after the previous one's `page.next`. The first page failing
  /// fails the catalog; a later one ends it with what was read, because the
  /// tail of that list holds areas with one or two lives each.
  Future<List<LiveArea>> areas() async {
    final pages = <List<LiveArea>>[];
    Map<String, String>? next = const {};
    for (var index = 0; index < ChzzkEndpoints.maxCategoryPages && next != null; index++) {
      final ChzzkCategoryPage result;
      try {
        final response = await get(ChzzkEndpoints.categories(next));
        result = ChzzkRoomParser.categoryPage(response.text, status: response.status);
      } on ChzzkFailure {
        if (index == 0) rethrow;
        break;
      }
      pages.add(result.areas);
      next = result.next;
    }
    final areas = ChzzkRoomParser.categories(pages);
    for (final area in areas) {
      final type = area.parentAreaId;
      if (type != null) _areaTypes[area.areaId] = type;
    }
    return areas;
  }

  /// The `categoryType` an area id belongs to: the one the catalog named, else
  /// null (a caller error the capabilities report, never a guessed path). The
  /// catalog is only read when no area is known yet, so an unknown id costs one
  /// request at most once per site.
  Future<String?> areaTypeOf(String areaId) async {
    if (_areaTypes[areaId] case final known?) return known;
    if (_areaTypes.isEmpty) await areas();
    return _areaTypes[areaId];
  }

  // Lives lists ---------------------------------------------------------------

  /// One page of the site-wide ([areaId] null) or one area's lives after
  /// [cursor]. An area whose type is unknown is refused as a caller error.
  Future<ChzzkListing> lives({String? areaId, String? cursor}) async {
    final areaType = areaId == null ? null : await areaTypeOf(areaId);
    if (areaId != null && areaType == null) {
      throw ChzzkFailure(ChzzkFailureKind.invalidArgument, 'area "$areaId" is not a chzzk area');
    }
    final query = ChzzkEndpoints.livesQuery(cursor);
    if (query == null) {
      throw const ChzzkFailure(ChzzkFailureKind.invalidArgument, 'the cursor is not one this adapter made');
    }
    final response = await get(ChzzkEndpoints.lives(areaType: areaType, areaId: areaId, query: query));
    final page = ChzzkRoomParser.lives(response.text, cursor: cursor, status: response.status);
    return (rooms: page.rooms, hasMore: page.hasMore, nextCursor: page.nextCursor);
  }

  /// Page [page] of the site-wide or one area's lives. With a [cursor] it is one
  /// request; without one the list is walked from page 1, because the platform
  /// has no page parameter (that many requests, inside [directoryDeadline]). A
  /// channel already shown on an earlier page of the walk is left out, since
  /// viewer counts move rows between requests.
  Future<ChzzkListing> listing({String? areaId, int page = 1, String? cursor}) async {
    if (page < 1 || page > ChzzkEndpoints.maxDirectoryPage) {
      throw ChzzkFailure(
        ChzzkFailureKind.invalidArgument,
        'page $page is outside 1–${ChzzkEndpoints.maxDirectoryPage}',
      );
    }
    if (cursor != null || page == 1) return await lives(areaId: areaId, cursor: cursor);
    var walked = lives(areaId: areaId);
    final shown = <String>{};
    for (var current = 1; ; current++) {
      final result = await walked.timeout(
        directoryDeadline,
        onTimeout: () =>
            throw ChzzkFailure(ChzzkFailureKind.network, 'directory page $page: walked past $directoryDeadline'),
      );
      if (current == page) {
        return (
          rooms: [
            for (final room in result.rooms)
              if (!shown.contains(room.roomId)) room,
          ],
          hasMore: result.hasMore,
          nextCursor: result.nextCursor,
        );
      }
      if (!result.hasMore || result.nextCursor == null) {
        return (rooms: const <LiveRoom>[], hasMore: false, nextCursor: null);
      }
      shown.addAll(result.rooms.map((room) => room.roomId));
      walked = lives(areaId: areaId, cursor: result.nextCursor);
    }
  }

  // Rooms ---------------------------------------------------------------------

  /// The channel and its latest live (two requests). An id that is not a
  /// channel id is refused without a request. The room carries its playback
  /// handle (the live's masters, or why it cannot play) and, for a live the
  /// platform gives a chat to, its chat handle; a live whose playback data
  /// cannot be read still stands as a room.
  Future<LiveRoom> detail(String roomId) async {
    final room = await read(roomId);
    final owner = room.owner;
    final live = room.live;
    final data = ChzzkRoomParser.roomData(owner.id, live, issuedAt: _now());
    if (live != null && live.isLive && live.media.isNotEmpty) {
      _playback.remove(owner.id);
    }
    return ChzzkRoomParser.room(owner, live).rebuild(
      (b) => b
        ..runtime = RoomRuntime.of(
          streamHandle: data,
          danmakuHandle: ChzzkRoomParser.danmakuArgs(owner, live),
        ).toBuilder(),
    );
  }

  /// The channel and its live: the room's two requests, with the id checked
  /// first.
  Future<({ChzzkChannel owner, ChzzkLive? live})> read(String roomId) async {
    final id = roomId.trim();
    if (!json.isChannelId(id)) throw ChzzkFailure(ChzzkFailureKind.notFound, 'not a channel id: $id');
    final channel = await get(ChzzkEndpoints.channel(id));
    final owner = ChzzkRoomParser.channelById(channel.text, channelId: id, status: channel.status);
    final live = await get(ChzzkEndpoints.liveDetail(id));
    return (owner: owner, live: ChzzkRoomParser.liveDetail(live.text, owner: owner, status: live.status));
  }

  // Streams -------------------------------------------------------------------

  /// The variants behind a channel's qualities and lines: those read while no
  /// line is due, else its masters while their tokens hold (two requests), else
  /// the room again and its masters (four). [fresh] always takes the long way —
  /// a recovery never replays a token the player just ran out of.
  Future<List<ChzzkVariant>> variantsOf(String channelId, {bool fresh = false}) async {
    final id = channelId.trim();
    final held = _playback[id];
    if (!fresh && held != null) {
      if (ChzzkPlayParser.linesFresh(ChzzkPlayParser.lines(held.variants), _now())) return held.variants;
      if (held.media.isNotEmpty && ChzzkPlayParser.mastersFresh(held.media, _now())) {
        return await _readMasters(id, held.media);
      }
    }
    final live = (await read(id)).live;
    if (live == null || !live.isLive) {
      throw ChzzkFailure(ChzzkFailureKind.streamUnavailable, '$id is offline');
    }
    if (live.media.isEmpty) throw ChzzkRoomParser.unavailable(live);
    return await _readMasters(id, live.media);
  }

  /// The masters of one live, read together. A master that fails — in its
  /// request or in its parsing — only loses its own lines, so a broken CDN
  /// answer never hides the streams of the other one; when every master fails,
  /// the first failure is thrown.
  Future<List<ChzzkVariant>> _readMasters(String channelId, List<ChzzkMedia> media) async {
    final issuedAt = _now();
    final answers = await Future.wait([
      for (final item in media)
        get(item.url).then<({ChzzkMedia media, String? body, ChzzkFailure? failure})>(
          (response) => (
            media: item,
            body: ChzzkPlayParser.master(response.text, what: '${item.id} master', status: response.status),
            failure: null,
          ),
          onError: (Object error, StackTrace stack) => (
            media: item,
            body: null,
            failure: error is ChzzkFailure
                ? error
                : ChzzkFailure(ChzzkFailureKind.apiChanged, '${item.id} master: $error', cause: error),
          ),
        ),
    ]);
    final variants = <ChzzkVariant>[];
    ChzzkFailure? first;
    for (final answer in answers) {
      if (answer.failure case final failure?) {
        first ??= failure;
        continue;
      }
      try {
        variants.addAll(ChzzkPlayParser.variants(answer.body!, media: answer.media, issuedAt: issuedAt));
      } on ChzzkFailure catch (failure) {
        first ??= failure;
      }
    }
    if (variants.isEmpty) {
      throw first ?? const ChzzkFailure(ChzzkFailureKind.streamUnavailable, 'no video variant');
    }
    _playback[channelId] = (media: media, variants: variants, issuedAt: issuedAt);
    return variants;
  }

  // Capability wiring ---------------------------------------------------------

  ChzzkRoomProvider? _room;
  ChzzkAreaProvider? _area;
  ChzzkDiscoveryProvider? _discovery;
  ChzzkSearchProvider? _search;
  ChzzkPlaybackProvider? _playbackProvider;
  ChzzkDanmakuProvider? _danmaku;
  ChzzkLinkResolver? _link;
  ChzzkRoomRefresh? _refresh;
  ChzzkStatusCheck? _status;

  /// The capability of type [T], or null when chzzk does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= ChzzkRoomProvider(site: this);
    final area = _area ??= ChzzkAreaProvider(site: this);
    final discovery = _discovery ??= ChzzkDiscoveryProvider(site: this);
    final search = _search ??= ChzzkSearchProvider(site: this);
    final playback = _playbackProvider ??= ChzzkPlaybackProvider(site: this);
    final danmaku = _danmaku ??= ChzzkDanmakuProvider(site: this);
    final link = _link ??= ChzzkLinkResolver(site: this);
    final refresh = _refresh ??= ChzzkRoomRefresh(site: this);
    final status = _status ??= ChzzkStatusCheck(refresh: refresh);
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
