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
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/missevan/api/missevan_endpoints.dart';
import 'package:live_sites/src/platforms/missevan/api/missevan_http.dart';
import 'package:live_sites/src/platforms/missevan/capabilities/missevan_area_provider.dart';
import 'package:live_sites/src/platforms/missevan/capabilities/missevan_discovery_provider.dart';
import 'package:live_sites/src/platforms/missevan/capabilities/missevan_link_resolver.dart';
import 'package:live_sites/src/platforms/missevan/capabilities/missevan_playback_provider.dart';
import 'package:live_sites/src/platforms/missevan/capabilities/missevan_room_provider.dart';
import 'package:live_sites/src/platforms/missevan/capabilities/missevan_search_provider.dart';
import 'package:live_sites/src/platforms/missevan/danmaku/missevan_danmaku_codec.dart';
import 'package:live_sites/src/platforms/missevan/danmaku/missevan_danmaku_session.dart';
import 'package:live_sites/src/platforms/missevan/missevan_manifest.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_failure.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How many room entries the adapter keeps for the play answers.
const _entryLimit = 64;

/// The Missevan (猫耳 FM) adapter (parsing in `parsers/`, the chat in
/// `danmaku/`): manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2).
///
/// Anonymous, like the site: no cookie and no account. Every request carries
/// [MissevanEndpoints.headers] and goes as `missevan`, so the app routes the
/// platform through its proxy setting. Every call is one request to
/// `fm.missevan.com/api/v2/`:
/// - the catalog is `meta/data`, the tabs grouped by namespace;
/// - recommendations and areas are pages of `chatroom/open/list`; an area is
///   asked for by its namespace;
/// - search is `chatroom/search` (a long keyword cut to
///   [MissevanEndpoints.maxKeywordLength] characters), or the room itself
///   for a room number or link;
/// - room entry reads `live/{id}`, which also holds the pull URLs, so
///   playing asks nothing more. Room entry also hands over the chat
///   arguments ([MissevanDanmakuArgs]), live or not; the connection is the
///   danmaku session's.
///
/// Failures are [MissevanFailure]s; nothing is disguised as an offline room.
final class MissevanSite implements LiveSite {
  /// Creates the adapter over [http]. [connect] makes the chat's socket
  /// (default [webSocketConnect]).
  MissevanSite({required this.http, this.connect = webSocketConnect});

  /// Transport.
  final MissevanHttp http;

  /// How the chat's socket is connected.
  final SocketConnector connect;

  /// The room entry read last for each room, oldest first: the pull URLs and
  /// chat arguments the capabilities hand out until the next entry.
  final Map<String, MissevanDetail> _entries = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => missevanManifest;

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

  /// The site's tabs as areas, grouped by namespace (see
  /// [MissevanRoomParser.areas]); one request.
  Future<List<LiveArea>> areas() async {
    final response = await http.get(Uri.https('fm.missevan.com', '${MissevanEndpoints.apiRoot}meta/data'));
    return MissevanRoomParser.areas(response.text, status: response.status);
  }

  /// Page [page] of [areaId]'s rooms, or of the recommendations when it is
  /// null: every live room of the answer, each once, and whether the site
  /// has another page. A page out of 1–[MissevanEndpoints.maxPage], a
  /// [pageSize] out of 1–[MissevanEndpoints.maxPageSize] (the site's pages
  /// are fixed at [MissevanEndpoints.serverPageSize] rows, so the size only
  /// has to be sane) or an area that is not a Missevan tab is a caller
  /// error, refused before any request.
  Future<({List<LiveRoom> rooms, bool hasMore})> directory(int page, {String? areaId, int pageSize = 20}) async {
    if (page < 1 || page > MissevanEndpoints.maxPage) {
      throw MissevanFailure(MissevanFailureKind.invalidArgument, 'page $page is out of 1–${MissevanEndpoints.maxPage}');
    }
    if (pageSize < 1 || pageSize > MissevanEndpoints.maxPageSize) {
      throw MissevanFailure(
        MissevanFailureKind.invalidArgument,
        'page size $pageSize is out of 1–${MissevanEndpoints.maxPageSize}',
      );
    }
    final filter = areaId == null ? const <String, String>{} : MissevanRoomParser.areaQuery(areaId);
    final response = await http.get(
      Uri.https('fm.missevan.com', '${MissevanEndpoints.apiRoot}chatroom/open/list', {'p': '$page', ...filter}),
    );
    return MissevanRoomParser.directoryPage(response.text, page: page, status: response.status);
  }

  // Search --------------------------------------------------------------------

  /// Rooms for [keyword], live or not:
  /// - a blank keyword or a [pageSize] below 1 finds nothing, without a
  ///   request;
  /// - a room number or `fm.missevan.com/live/{id}` link finds that room on
  ///   page 1 only, or nothing when it does not exist;
  /// - another link (a URL with a scheme and host) finds nothing;
  /// - anything else is a `chatroom/search` keyword, [pageSize] a page; a
  ///   keyword over [MissevanEndpoints.maxKeywordLength] characters is cut
  ///   to its first ones. A keyword with control characters, a page out of
  ///   1–[MissevanEndpoints.maxPage] or a [pageSize] over
  ///   [MissevanEndpoints.maxPageSize] is a caller error, without a request.
  Future<({List<LiveRoom> rooms, bool? hasMore})> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final input = keyword.trim();
    if (input.isEmpty || pageSize < 1) return (rooms: const <LiveRoom>[], hasMore: null);
    final roomId = MissevanEndpoints.isId(input) ? input : MissevanEndpoints.roomIdFromUri(Uri.tryParse(input));
    if (roomId != null) {
      if (page != 1) return (rooms: const <LiveRoom>[], hasMore: null);
      try {
        return (rooms: [(await _detail(roomId, media: false)).room], hasMore: null);
      } on MissevanFailure catch (failure) {
        if (failure.kind != MissevanFailureKind.notFound) rethrow;
        return (rooms: const <LiveRoom>[], hasMore: null);
      }
    }
    if (_isLink(input)) return (rooms: const <LiveRoom>[], hasMore: null);
    final text = MissevanRoomParser.searchKeyword(input);
    if (text == null) {
      throw const MissevanFailure(MissevanFailureKind.invalidArgument, 'keyword has control characters');
    }
    if (page < 1 || page > MissevanEndpoints.maxPage) {
      throw MissevanFailure(MissevanFailureKind.invalidArgument, 'page $page is out of 1–${MissevanEndpoints.maxPage}');
    }
    if (pageSize > MissevanEndpoints.maxPageSize) {
      throw MissevanFailure(
        MissevanFailureKind.invalidArgument,
        'page size $pageSize is out of 1–${MissevanEndpoints.maxPageSize}',
      );
    }
    final response = await http.get(
      Uri.https('fm.missevan.com', '${MissevanEndpoints.apiRoot}chatroom/search', {
        's': text,
        'p': '$page',
        'page_size': '$pageSize',
      }),
    );
    final result = MissevanRoomParser.searchPage(
      response.text,
      page: page,
      pageSize: pageSize,
      status: response.status,
    );
    return (rooms: result.rooms, hasMore: result.hasMore);
  }

  /// Whether [input] is a link (`scheme://…`) rather than a keyword.
  static bool _isLink(String input) {
    final uri = Uri.tryParse(input);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  // Rooms ---------------------------------------------------------------------

  /// `live/{id}` as the room [roomId], with the pull URLs when live and the
  /// chat arguments live or not; an id that is not a room number is
  /// not-found without a request. The entry is kept for the play answers.
  Future<LiveRoom> detail(String roomId) async {
    final entry = await _detail(roomId.trim());
    _entries
      ..remove(entry.room.roomId)
      ..[entry.room.roomId] = entry;
    while (_entries.length > _entryLimit) {
      _entries.remove(_entries.keys.first);
    }
    return entry.room.rebuild(
      (b) => b..runtime = RoomRuntime.of(streamHandle: entry.data, danmakuHandle: entry.args).toBuilder(),
    );
  }

  /// The entry of [roomId], without the v2 handles around it; an id that is
  /// not a room number is not-found without a request.
  Future<MissevanDetail> _detail(String roomId, {bool media = true}) async {
    if (!MissevanEndpoints.isId(roomId)) {
      throw MissevanFailure(MissevanFailureKind.notFound, 'not a room id: $roomId');
    }
    final response = await http.get(Uri.https('fm.missevan.com', '${MissevanEndpoints.apiRoot}live/$roomId'));
    return MissevanRoomParser.detail(response.text, roomId: roomId, media: media, status: response.status);
  }

  // Streams -------------------------------------------------------------------

  /// The room entry the room's streams come from: the one its room entry
  /// brought, or a fresh entry — the capabilities are asked by room id alone.
  Future<MissevanDetail> _entry(String roomId) async {
    final kept = _entries[roomId.trim()];
    if (kept != null) return kept;
    await detail(roomId);
    return _entries[roomId.trim()]!;
  }

  /// The one quality 原画, from the entry room entry brought: no request. A
  /// room the platform called offline, or one live without a pull URL, says
  /// why.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async => MissevanRoomParser.qualities(await _entry(roomId));

  /// The lines of [quality] (a stored `hls` or `flv` names the one quality,
  /// null the default) with the media headers and their leases.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async =>
      MissevanRoomParser.lines(await _entry(roomId), quality?.qualityId);

  // Capability wiring ---------------------------------------------------------

  MissevanRoomProvider? _room;
  MissevanAreaProvider? _area;
  MissevanDiscoveryProvider? _discovery;
  MissevanSearchProvider? _search;
  MissevanPlaybackProvider? _playback;
  MissevanDanmakuProvider? _danmaku;
  MissevanLinkResolver? _link;

  /// The capability of type [T], or null when Missevan does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= MissevanRoomProvider(site: this);
    final area = _area ??= MissevanAreaProvider(site: this);
    final discovery = _discovery ??= MissevanDiscoveryProvider(site: this);
    final search = _search ??= MissevanSearchProvider(site: this);
    final playback = _playback ??= MissevanPlaybackProvider(site: this);
    final danmaku = _danmaku ??= MissevanDanmakuProvider(site: this);
    final link = _link ??= MissevanLinkResolver(site: this);
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
