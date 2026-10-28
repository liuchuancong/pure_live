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
import 'package:live_sites/src/platforms/seventeenlive/api/seventeenlive_endpoints.dart';
import 'package:live_sites/src/platforms/seventeenlive/api/seventeenlive_http.dart';
import 'package:live_sites/src/platforms/seventeenlive/capabilities/seventeenlive_area_provider.dart';
import 'package:live_sites/src/platforms/seventeenlive/capabilities/seventeenlive_discovery_provider.dart';
import 'package:live_sites/src/platforms/seventeenlive/capabilities/seventeenlive_link_resolver.dart';
import 'package:live_sites/src/platforms/seventeenlive/capabilities/seventeenlive_playback_provider.dart';
import 'package:live_sites/src/platforms/seventeenlive/capabilities/seventeenlive_room_provider.dart';
import 'package:live_sites/src/platforms/seventeenlive/capabilities/seventeenlive_room_refresh.dart';
import 'package:live_sites/src/platforms/seventeenlive/capabilities/seventeenlive_search_provider.dart';
import 'package:live_sites/src/platforms/seventeenlive/capabilities/seventeenlive_status_check.dart';
import 'package:live_sites/src/platforms/seventeenlive/danmaku/seventeenlive_danmaku_session.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_failure.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_room_parser.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One page of the directory: its cards, whether another page exists and the
/// cursor that reads it.
typedef SeventeenLiveListing = ({List<LiveRoom> rooms, bool hasMore, String? nextCursor});

/// The 17LIVE (イチナナ) adapter: manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2), parsing in `parsers/`.
///
/// **17LIVE.** Anonymous, like the website itself: no cookie, no account, no
/// signature. A room is the broadcaster's fixed `liveStreamID` (1 to 12 digits),
/// kept as asked for; its `userID` is a UUID and names the pull streams, which
/// carry no signature and do not expire. Every request carries the headers of
/// the endpoint it goes to (the catalog's, or the room page's as `Referer`) and
/// follows no redirect — a 3xx is a network failure here, not an answer.
///
/// **Catalog.** One category of three regions, Japan, Taiwan and Hong Kong
/// ([SeventeenLiveEndpoints.areas]), built without a request.
///
/// **Directory.** The website's recommendation sections of one region, one
/// request a page by cursor; a caller that names a page *number* instead is
/// walked there from page 1 (that many requests, at most
/// [SeventeenLiveEndpoints.maxDirectoryPage]), because the platform has no page
/// parameter at all. Recommendations are the Japan region, as the reference
/// asked; the page size is never sent — it is the platform's own 20 rows a
/// section that a page is cut to.
///
/// **Search.** One `lives/<id>` for a room id or a room/profile link, else one
/// `liveStreams/search` of the keyword cut to
/// [SeventeenLiveEndpoints.maxKeywordLength] characters (current broadcasts
/// only, one page).
///
/// **Rooms and streams.** The room, its state and its pull URLs all come from
/// one `lives/<id>`: a room that cannot be played is still a room, and its
/// handle says why (offline, a state the platform did not name, a locked live,
/// no readable pull URL). The qualities keep the answer's provider order, which
/// is the only CDN serving at a time (REG-17LIVE-002); a line request that the
/// held answer cannot serve enters the room again, so recovery reads the CDN
/// that serves now.
///
/// Failures are [SeventeenLiveFailure]s; nothing is disguised as an offline room.
final class SeventeenLiveSite implements LiveSite {
  /// Creates the adapter over [http]. [preferH264] reads "优先 H.264" (on by
  /// default) every time the qualities are listed: on, the H.264 transcode comes
  /// first and is the default; off, 原画 does
  /// (`SeventeenLivePlayParser.playQualities`).
  SeventeenLiveSite({required this.http, bool Function()? preferH264}) : preferH264 = preferH264 ?? _on;

  /// Transport.
  final SeventeenLiveHttp http;

  /// The "优先 H.264" setting, read per request so a change needs no new adapter.
  final bool Function() preferH264;

  static bool _on() => true;

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => seventeenliveManifest;

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

  /// A GET with the headers [headers] and the caller's cancellation.
  Future<SeventeenLiveResponse> get(
    Uri url, {
    required Map<String, String> headers,
    CancelToken? cancel,
    Duration? timeout,
  }) => http.get(url, headers: headers, cancel: cancel, timeout: timeout);

  /// The room answer, `lives/<roomId>`, asked with the room page as its
  /// `Referer`.
  Future<SeventeenLiveResponse> lives(String roomId) =>
      get(SeventeenLiveEndpoints.lives(roomId), headers: SeventeenLiveEndpoints.requestHeaders(roomId));

  static String _checkedId(String roomId) =>
      SeventeenLiveRoomParser.normalizeRoomId(roomId) ??
      (throw SeventeenLiveFailure(SeventeenLiveFailureKind.notFound, 'not a room id: $roomId'));

  // Catalog -------------------------------------------------------------------

  /// The catalog: the one category's three regions
  /// ([SeventeenLiveEndpoints.areas]), without a request.
  List<LiveArea> areas() => SeventeenLiveEndpoints.areas;

  /// The `region` code an area id asks for: Japan for null or blank (the
  /// recommendations), else the id itself in any case. An id of no region the
  /// platform serves is a caller error, never a guessed region.
  String regionOf(String? areaId) =>
      SeventeenLiveEndpoints.regionFor(areaId) ??
      (throw SeventeenLiveFailure(SeventeenLiveFailureKind.invalidArgument, 'area "$areaId" is not a 17LIVE region'));

  // Directory -----------------------------------------------------------------

  /// One sections page after [cursor] (null asks the first) of [region].
  Future<SeventeenLiveListing> sections({String? region, String? cursor}) async {
    SeventeenLiveRoomParser.checkCursor(cursor);
    final response = await get(
      SeventeenLiveEndpoints.sections(cursor: cursor, regionCode: region ?? SeventeenLiveEndpoints.region),
      headers: SeventeenLiveEndpoints.catalogHeaders,
    );
    final result = SeventeenLiveRoomParser.sectionsPage(response.text, cursor: cursor, status: response.status);
    return (rooms: result.rooms, hasMore: result.hasMore, nextCursor: result.nextCursor);
  }

  /// Page [page] of [region]'s directory. With a [cursor] it is one request and
  /// the cursor is the caller's own sequence; without one the list is walked from
  /// page 1 (that many requests), because the platform has no page parameter. A
  /// directory that ends first gives an empty last page. [pageSize] cuts the
  /// page, never the walk: it is not sent.
  Future<SeventeenLiveListing> directory({String? region, int page = 1, String? cursor, int pageSize = 20}) async {
    if (page < 1 || page > SeventeenLiveEndpoints.maxDirectoryPage) {
      throw SeventeenLiveFailure(
        SeventeenLiveFailureKind.invalidArgument,
        'page $page is outside 1–${SeventeenLiveEndpoints.maxDirectoryPage}',
      );
    }
    if (pageSize < 1) throw SeventeenLiveFailure(SeventeenLiveFailureKind.invalidArgument, 'page size $pageSize');
    if (cursor != null || page == 1) {
      final result = await sections(region: region, cursor: cursor);
      return (
        rooms: result.rooms.take(pageSize).toList(growable: false),
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
      );
    }
    final code = region ?? SeventeenLiveEndpoints.region;
    String? walked;
    for (var current = 1; ; current++) {
      final result = await sections(region: code, cursor: walked);
      if (current == page) {
        return (
          rooms: result.rooms.take(pageSize).toList(growable: false),
          hasMore: result.hasMore,
          nextCursor: result.nextCursor,
        );
      }
      if (!result.hasMore || result.nextCursor == null) {
        return (rooms: const <LiveRoom>[], hasMore: false, nextCursor: null);
      }
      walked = result.nextCursor;
    }
  }

  // Search --------------------------------------------------------------------

  /// The search, one page only:
  /// - a page other than 1 or a [pageSize] below 1 finds nothing;
  /// - a room link (see [SeventeenLiveRoomParser.roomIdFromUrl]; `www.17.live`
  ///   too) or a room id finds that room, live or not (one `lives/<id>`; nothing
  ///   when there is no such room);
  /// - another web address (`<scheme>://…`) or a blank keyword finds nothing;
  /// - anything else is one `liveStreams/search` of the keyword cut to
  ///   [SeventeenLiveEndpoints.maxKeywordLength] characters: current broadcasts,
  ///   the first [pageSize]. A keyword with a colon (`Re:Zero`) or one longer than
  ///   the limit is searched, as the website does.
  Future<List<LiveRoom>> search(String keyword, {int page = 1, int pageSize = 20}) async {
    if (page != 1 || pageSize < 1) return const [];
    final text = keyword.trim();
    final roomId = SeventeenLiveRoomParser.roomIdFromUrl(text) ?? SeventeenLiveRoomParser.normalizeRoomId(text);
    if (roomId != null) {
      try {
        return [await refresh(roomId)];
      } on SeventeenLiveFailure catch (failure) {
        if (failure.kind == SeventeenLiveFailureKind.notFound) return const [];
        rethrow;
      }
    }
    final query = SeventeenLiveRoomParser.searchKeyword(text);
    if (query.isEmpty || SeventeenLiveRoomParser.isUrl(text)) return const [];
    final response = await get(SeventeenLiveEndpoints.search(query), headers: SeventeenLiveEndpoints.catalogHeaders);
    return List.unmodifiable(
      SeventeenLiveRoomParser.searchRooms(response.text, status: response.status).take(pageSize),
    );
  }

  // Rooms ---------------------------------------------------------------------

  /// Room entry: one `lives/<id>`, whose pull URLs become the qualities in the
  /// stream handle and whose channel becomes the danmaku handle. A room that
  /// cannot be played is entered all the same; its handle says why. This is also
  /// the refresh (this contract has no separate refresher) and the recording
  /// entry, which 3.x read the same answer for.
  Future<LiveRoom> detail(String roomId) async {
    final id = _checkedId(roomId);
    final response = await lives(id);
    return SeventeenLiveRoomParser.enteredRoom(response.text, roomId: id, status: response.status);
  }

  /// The room of [roomId] without its streams (a follow-card refresh, a search by
  /// room): one `lives/<id>`.
  Future<LiveRoom> refresh(String roomId) async {
    final id = _checkedId(roomId);
    final response = await lives(id);
    return SeventeenLiveRoomParser.refreshRoom(response.text, roomId: id, status: response.status);
  }

  /// What the room of [roomId] keeps for playback: [detail] and its handle.
  Future<SeventeenLiveRoomData> playback(String roomId) async {
    final handle = (await detail(roomId)).runtime.streamHandle;
    if (handle is! SeventeenLiveRoomData) {
      throw SeventeenLiveFailure(SeventeenLiveFailureKind.apiChanged, 'lives/$roomId: no playback handle');
    }
    return handle;
  }

  // Capability wiring ---------------------------------------------------------

  SeventeenLiveRoomProvider? _room;
  SeventeenLiveAreaProvider? _area;
  SeventeenLiveDiscoveryProvider? _discovery;
  SeventeenLiveSearchProvider? _search;
  SeventeenLivePlaybackProvider? _playback;
  SeventeenLiveDanmakuProvider? _danmaku;
  SeventeenLiveLinkResolver? _link;
  SeventeenLiveRoomRefresh? _refresh;
  SeventeenLiveStatusCheck? _status;

  /// The capability of type [T], or null when 17LIVE does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= SeventeenLiveRoomProvider(site: this);
    final area = _area ??= SeventeenLiveAreaProvider(site: this);
    final discovery = _discovery ??= SeventeenLiveDiscoveryProvider(site: this);
    final search = _search ??= SeventeenLiveSearchProvider(site: this);
    final playback = _playback ??= SeventeenLivePlaybackProvider(site: this);
    final danmaku = _danmaku ??= SeventeenLiveDanmakuProvider(site: this);
    final link = _link ??= SeventeenLiveLinkResolver(site: this);
    final refresh = _refresh ??= SeventeenLiveRoomRefresh(site: this);
    final status = _status ??= SeventeenLiveStatusCheck(refresh: refresh);
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
