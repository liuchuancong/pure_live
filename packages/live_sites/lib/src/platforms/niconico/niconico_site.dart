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
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_endpoints.dart';
import 'package:live_sites/src/platforms/niconico/api/niconico_http.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_area_provider.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_discovery_provider.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_link_resolver.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_playback_provider.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_room_provider.dart';
import 'package:live_sites/src/platforms/niconico/capabilities/niconico_search_provider.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_danmaku_session.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_seat_session.dart';
import 'package:live_sites/src/platforms/niconico/niconico_manifest.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_room_parser.dart';

// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

// The adapter spells its class name in its constructor; the `.new` shorthand
// would read as a field declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The niconico adapter: manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2); requests in `api/`, parsing in `parsers/`, features
/// in `capabilities/`, the watching seat and the comment feed in `danmaku/`.
///
/// Everything runs anonymously (no cookie is sent to any page or API); a
/// program whose watch page grants an anonymous viewer access is playable, one
/// that needs a login, is country-restricted, or is private, paid or
/// followers-only reports the matching [NiconicoFailure] instead of a stream.
///
/// Note: this adapter is NOT yet wired into the built-in site registry.
final class NiconicoSite implements LiveSite {
  /// Creates the adapter over [http]; [now] is injectable for tests.
  NiconicoSite({required this.http, DateTime Function()? now}) : now = now ?? DateTime.now;

  /// Transport (the capabilities' and the comment feed's).
  final NiconicoHttp http;

  /// Injectable clock (the seat grant's cookies expire against it).
  final DateTime Function() now;

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => niconicoManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Pages ---------------------------------------------------------------------

  /// GETs the watch page of [roomId] and parses it into a [NiconicoWatch].
  Future<NiconicoWatch> watch(String roomId) async {
    final id = roomId.trim();
    if (!NiconicoEndpoints.isRoomId(id)) {
      throw NiconicoFailure(NiconicoFailureKind.notFound, 'room id "$id" is not a niconico room');
    }
    final response = await http.get(NiconicoEndpoints.watchPage(id), headers: NiconicoEndpoints.headers);
    return NiconicoRoomParser.watch(response.text, roomId: id, status: response.status);
  }

  /// The room at [roomId], its watch snapshot riding in the room's runtime
  /// handles for the seat (playback and comments open a seat without reading
  /// the page twice).
  Future<LiveRoom> detail(String roomId) async => NiconicoRoomParser.room(await watch(roomId));

  /// One recent-tab page of [tab] (an unknown tab reads `common`).
  Future<({List<LiveRoom> rooms, bool hasMore})> recent(String tab, int page) async {
    final name = NiconicoEndpoints.tabs.contains(tab) ? tab : NiconicoEndpoints.tabs.first;
    final number = page < 1 ? 1 : page;
    final response = await http.get(NiconicoEndpoints.recentPrograms(name, number), headers: NiconicoEndpoints.headers);
    return NiconicoRoomParser.listPage(response.text, page: number, search: false, status: response.status);
  }

  /// One on-air search page for [keyword] (a blank keyword answers empty
  /// without a request).
  Future<List<LiveSearchResult>> search(String keyword, int page) async {
    final text = keyword.trim();
    if (text.isEmpty) return const [];
    final number = page < 1 ? 1 : page;
    final response = await http.get(NiconicoEndpoints.searchPrograms(text, number), headers: NiconicoEndpoints.headers);
    return NiconicoRoomParser.searchRooms(response.text, status: response.status, page: number);
  }

  /// GETs [url] with [headers] (the playback provider's media transport).
  Future<NiconicoResponse> httpGet(Uri url, {Map<String, String> headers = const {}}) =>
      http.get(url, headers: headers);

  // Seat ----------------------------------------------------------------------

  /// Opens a watching seat on [roomId]'s program: the watch page, then the
  /// seat WebSocket, which names the comment server. A room that cannot be
  /// watched now (offline, restricted, gone) throws a [NiconicoFailure] of the
  /// matching kind, never a seat.
  Future<NiconicoSeat> openSeat(String roomId) async {
    final snapshot = await watch(roomId);
    final socket = snapshot.socket;
    if (socket == null) throw _notPlayable(snapshot);
    final seat = NiconicoSeat(socket, now: now);
    await seat.connect();
    return seat;
  }

  /// Why an on-air [snapshot]'s stream cannot be opened anonymously.
  static NiconicoFailure _notPlayable(NiconicoWatch snapshot) => switch (snapshot.restriction) {
    LiveRestriction.regionBlocked => NiconicoFailure(
      NiconicoFailureKind.regionBlocked,
      '${snapshot.programId}: country restriction',
    ),
    LiveRestriction.needsLogin => NiconicoFailure(NiconicoFailureKind.needsLogin, '${snapshot.programId}: needLogin'),
    LiveRestriction.private => NiconicoFailure(NiconicoFailureKind.streamUnavailable, '${snapshot.programId}: private'),
    LiveRestriction.paid => NiconicoFailure(NiconicoFailureKind.streamUnavailable, '${snapshot.programId}: paid'),
    LiveRestriction.subscribersOnly => NiconicoFailure(
      NiconicoFailureKind.streamUnavailable,
      '${snapshot.programId}: followers-only',
    ),
    _ => NiconicoFailure(NiconicoFailureKind.streamUnavailable, '${snapshot.programId} is ${snapshot.status.name}'),
  };

  // Capability wiring ---------------------------------------------------------

  NiconicoRoomProvider? _room;
  NiconicoAreaProvider? _area;
  NiconicoDiscoveryProvider? _discovery;
  NiconicoSearchProvider? _search;
  NiconicoPlaybackProvider? _playback;
  NiconicoDanmakuProvider? _danmaku;
  NiconicoLinkResolver? _link;

  /// The capability of type [T], or null when niconico does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= NiconicoRoomProvider(site: this);
    final area = _area ??= NiconicoAreaProvider(site: this);
    final discovery = _discovery ??= NiconicoDiscoveryProvider(site: this);
    final search = _search ??= NiconicoSearchProvider(site: this);
    final playback = _playback ??= NiconicoPlaybackProvider(site: this);
    final danmaku = _danmaku ??= NiconicoDanmakuProvider(site: this);
    final link = _link ??= NiconicoLinkResolver(site: this);
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
