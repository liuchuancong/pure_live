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
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/twitcasting/api/twitcasting_endpoints.dart';
import 'package:live_sites/src/platforms/twitcasting/api/twitcasting_http.dart';
import 'package:live_sites/src/platforms/twitcasting/capabilities/twitcasting_area_provider.dart';
import 'package:live_sites/src/platforms/twitcasting/capabilities/twitcasting_discovery_provider.dart';
import 'package:live_sites/src/platforms/twitcasting/capabilities/twitcasting_link_resolver.dart';
import 'package:live_sites/src/platforms/twitcasting/capabilities/twitcasting_playback_provider.dart';
import 'package:live_sites/src/platforms/twitcasting/capabilities/twitcasting_room_provider.dart';
import 'package:live_sites/src/platforms/twitcasting/capabilities/twitcasting_search_provider.dart';
import 'package:live_sites/src/platforms/twitcasting/danmaku/twitcasting_danmaku_session.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_failure.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_room_parser.dart';
import 'package:live_sites/src/platforms/twitcasting/twitcasting_manifest.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How long a list or search snapshot serves the pages after the first (the
/// unified paging rule: 20–30 s). The first page always fetches a new one.
const _snapshotLifetime = Duration(seconds: 30);

/// Snapshots kept (the oldest is dropped first).
const _snapshotLimit = 16;

/// One answer of a list (`top/category`) or a search, paged locally: one
/// entry per row, null for a row left out, and when it arrived.
typedef _Snapshot = ({DateTime fetchedAt, List<LiveRoom?> window});

/// One page cut from a window: its rooms and whether rows remain behind it.
typedef TwitcastingWindowPage = ({List<LiveRoom> rooms, bool hasMore});

/// The TwitCasting adapter (3.x's `TwitcastingSite`; parsing in `parsers/`,
/// the chat in `danmaku/`): manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2).
///
/// Every request is anonymous (3.x had no TwitCasting account) and goes as
/// `twitcasting`, so the app routes the platform through its proxy setting;
/// each carries [TwitcastingEndpoints.headers]. The catalog is the homepage's
/// tabs, lists are the one `top/category` window, search is the website's
/// text search, a room is its channel page plus `streamserver.php`, and a
/// stream is the tier playlist that answer names. A list or search answer is
/// kept for 30 s and later pages are cut from it. Room ids stay as the user
/// asked for them; requests use the lower-case channel. Failures are
/// [TwitcastingFailure]s; nothing is disguised as an offline room.
final class TwitcastingSite implements LiveSite {
  /// Creates the adapter over [http]. [connect] makes the chat's socket
  /// (default [webSocketConnect]); [now] (the lists' start times, the
  /// snapshots' age) is injectable for tests.
  TwitcastingSite({required this.http, this.connect = webSocketConnect, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Transport.
  final TwitcastingHttp http;

  /// How the chat's socket is connected.
  final SocketConnector connect;

  final DateTime Function() _now;

  /// The list and search answers, by `top|<tab>` and `search|<keyword>`.
  final Map<String, _Snapshot> _snapshots = {};

  /// The stream data of the channel whose room was entered last, by
  /// lower-case channel: the qualities and lines the capabilities hand out
  /// until the next entry. An offline answer is kept too, so a channel the
  /// platform called offline is not asked again (REG-TWITCASTING-001).
  final Map<String, TwitcastingRoomData> _streams = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => twitcastingManifest;

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

  /// The answer [key] for page [page]: page 1 always fetches a new one with
  /// [fetch]; a later page uses the kept one while it is under 30 s old, so
  /// the pages of one browse come from one answer (12-4, the unified paging
  /// rule). A failed fetch keeps nothing.
  Future<List<LiveRoom?>> _snapshot(String key, int page, Future<List<LiveRoom?>> Function() fetch) async {
    final kept = _snapshots[key];
    if (page > 1 && kept != null && _now().difference(kept.fetchedAt) < _snapshotLifetime) {
      return kept.window;
    }
    final window = await fetch();
    _snapshots
      ..remove(key)
      ..[key] = (fetchedAt: _now(), window: window);
    if (_snapshots.length > _snapshotLimit) _snapshots.remove(_snapshots.keys.first);
    return window;
  }

  /// Page [page] of [pageSize] rows of the window [category] names (the
  /// whole site's when it is empty), cut from the one `top/category` answer
  /// as 3.x cut it. A page or page size outside what the platform serves is
  /// a caller error; a page past the window is empty without a request.
  Future<TwitcastingWindowPage> _directory(String category, {required int page, required int pageSize}) async {
    if (page < 1 || page > 10000 || pageSize < 1 || pageSize > TwitcastingEndpoints.directoryWindow) {
      throw TwitcastingFailure(TwitcastingFailureKind.invalidArgument, 'invalid TwitCasting page $page of $pageSize');
    }
    final offset = (page - 1) * pageSize;
    if (offset >= TwitcastingEndpoints.directoryWindow) return (rooms: const <LiveRoom>[], hasMore: false);
    final window = await _snapshot('top|$category', page, () async {
      final response = await http.get(TwitcastingEndpoints.directoryUrl(category));
      return TwitcastingRoomParser.directoryRows(response.text, status: response.status, now: _now());
    });
    return (
      rooms: TwitcastingRoomParser.slice(window, offset: offset, pageSize: pageSize),
      hasMore: offset + pageSize < window.length,
    );
  }

  // Catalog and lists ---------------------------------------------------------

  /// The homepage's top tabs as the areas of the one category, in page
  /// order.
  Future<List<LiveArea>> catalog() async {
    final response = await http.get(TwitcastingEndpoints.homeUrl());
    return TwitcastingRoomParser.areas(response.text, status: response.status);
  }

  /// Page [page] of [pageSize] rows of the whole site's window
  /// (`top/category` without an id).
  Future<TwitcastingWindowPage> recommend(int page, int pageSize) => _directory('', page: page, pageSize: pageSize);

  /// The window of a homepage tab; see [_directory] for the paging. A key
  /// that is not a tab key is a caller error, refused before any request.
  Future<TwitcastingWindowPage> areaRooms(String areaId, {required int page, required int pageSize}) async {
    if (!TwitcastingEndpoints.areaIdPattern.hasMatch(areaId)) {
      throw TwitcastingFailure(TwitcastingFailureKind.invalidArgument, 'area "$areaId" is not a TwitCasting tab');
    }
    return await _directory(areaId, page: page, pageSize: pageSize);
  }

  // Search --------------------------------------------------------------------

  /// Live broadcasts matching [keyword], private ones included and marked
  /// (12-5): the search page holds at most
  /// [TwitcastingEndpoints.searchWindow]. Page 1 asks for it and page [page]
  /// of [pageSize] (1–50) is cut from it; a later page is cut from the same
  /// answer while it is under 30 s old (12-4; 3.x asked again for each
  /// page), and a page past 50 is empty without a request. A channel link
  /// finds that channel, live or not, on page 1 (an unknown one finds
  /// nothing); other TwitCasting links find nothing. A blank keyword gives
  /// nothing without a request; a page out of range, a page size over 50 or
  /// a keyword over 100 characters is a caller error.
  Future<TwitcastingWindowPage> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final query = keyword.trim();
    if (page < 1 ||
        page > 10000 ||
        pageSize < 1 ||
        pageSize > TwitcastingEndpoints.searchWindow ||
        query.length > 100) {
      throw TwitcastingFailure(
        TwitcastingFailureKind.invalidArgument,
        'invalid TwitCasting search: page $page of $pageSize, ${query.length} characters',
      );
    }
    if (query.isEmpty || (page - 1) * pageSize >= TwitcastingEndpoints.searchWindow) {
      return (rooms: const <LiveRoom>[], hasMore: false);
    }
    final link = Uri.tryParse(query);
    if (link != null && TwitcastingEndpoints.hosts.contains(link.host.toLowerCase())) {
      final channel = TwitcastingEndpoints.channelFromUri(link);
      if (channel == null || page != 1) return (rooms: const <LiveRoom>[], hasMore: false);
      try {
        return (rooms: [await detail(channel)], hasMore: false);
      } on TwitcastingFailure catch (failure) {
        if (failure.kind != TwitcastingFailureKind.notFound) rethrow;
        return (rooms: const <LiveRoom>[], hasMore: false);
      }
    }
    final window = await _snapshot('search|$query', page, () async {
      final response = await http.get(TwitcastingEndpoints.searchUrl(query));
      return TwitcastingRoomParser.searchRows(response.text, status: response.status);
    });
    final offset = (page - 1) * pageSize;
    return (
      rooms: TwitcastingRoomParser.slice(window, offset: offset, pageSize: pageSize),
      hasMore: offset + pageSize < window.length,
    );
  }

  // Rooms ---------------------------------------------------------------------

  /// The room of [roomId] (3.x's two requests): the channel page, then
  /// `streamserver.php` for the state and the broadcast. A page asking for
  /// the secret word asks `streamserver.php` too (3.x stopped there), so a
  /// protected broadcast shows as live. An id that is not a channel is
  /// not-found without a request.
  Future<LiveRoom> detail(String roomId) async {
    final (:requested, :channel) = _channel(roomId);
    final page = await http.get(TwitcastingEndpoints.channelUrl(channel));
    final parsed = TwitcastingRoomParser.channelPage(
      page.text,
      roomId: requested,
      channel: channel,
      status: page.status,
    );
    final stream = await _stream(channel);
    _streams[channel] = stream;
    return TwitcastingRoomParser.roomDetail(parsed, stream);
  }

  /// [roomId] trimmed, and its lower-case channel; not-found when it is not
  /// one.
  static ({String requested, String channel}) _channel(String roomId) {
    final requested = roomId.trim();
    final channel = TwitcastingEndpoints.channelName(requested);
    if (channel == null) {
      throw TwitcastingFailure(TwitcastingFailureKind.notFound, 'room id "$requested" is not a TwitCasting channel');
    }
    return (requested: requested, channel: channel);
  }

  /// `streamserver.php` for [channel], as answered now.
  Future<TwitcastingRoomData> _stream(String channel) async {
    final response = await http.get(TwitcastingEndpoints.streamServerUrl(channel));
    return TwitcastingRoomParser.streamServer(response.text, status: response.status);
  }

  // Streams -------------------------------------------------------------------

  /// The stream data of [roomId]: the one its room entry brought, or a fresh
  /// `streamserver.php` answer — the capabilities are asked by room id
  /// alone. A kept answer decides (a channel the platform called offline is
  /// not asked again, REG-TWITCASTING-001).
  Future<TwitcastingRoomData> _broadcast(String roomId) async {
    final requested = roomId.trim();
    final channel = TwitcastingEndpoints.channelName(requested);
    if (channel == null) {
      throw TwitcastingFailure(
        TwitcastingFailureKind.streamUnavailable,
        'room id "$requested" is not a TwitCasting channel',
      );
    }
    final kept = _streams[channel];
    if (kept != null) return kept;
    final data = await _stream(channel);
    _streams[channel] = data;
    return data;
  }

  /// The qualities of the broadcast [roomId] carries, best first: 3.x's
  /// `HLS high`, `HLS medium`, `HLS low`, without a request when the room
  /// entry brought the broadcast. A channel that is not broadcasting has
  /// none, and neither has a password-protected one: stream-unavailable.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async =>
      TwitcastingRoomParser.qualities(await _broadcast(roomId));

  /// The playlist of [quality] (the best tier when it is null) with the
  /// media headers; no lease, for the URL carries no signature or expiry.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async => TwitcastingRoomParser.lines(
    await _broadcast(roomId),
    quality?.qualityId ?? TwitcastingEndpoints.qualityKeys.first,
  );

  // Capability wiring ---------------------------------------------------------

  TwitcastingRoomProvider? _room;
  TwitcastingAreaProvider? _area;
  TwitcastingDiscoveryProvider? _discovery;
  TwitcastingSearchProvider? _search;
  TwitcastingPlaybackProvider? _playback;
  TwitcastingDanmakuProvider? _danmaku;
  TwitcastingLinkResolver? _link;

  /// The capability of type [T], or null when TwitCasting does not support
  /// it (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= TwitcastingRoomProvider(site: this);
    final area = _area ??= TwitcastingAreaProvider(site: this);
    final discovery = _discovery ??= TwitcastingDiscoveryProvider(site: this);
    final search = _search ??= TwitcastingSearchProvider(site: this);
    final playback = _playback ??= TwitcastingPlaybackProvider(site: this);
    final danmaku = _danmaku ??= TwitcastingDanmakuProvider(site: this);
    final link = _link ??= TwitcastingLinkResolver(site: this);
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
