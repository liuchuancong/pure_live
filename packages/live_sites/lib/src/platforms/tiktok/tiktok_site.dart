// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
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
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/tiktok/api/tiktok_endpoints.dart';
import 'package:live_sites/src/platforms/tiktok/api/tiktok_http.dart';
import 'package:live_sites/src/platforms/tiktok/capabilities/tiktok_discovery_provider.dart';
import 'package:live_sites/src/platforms/tiktok/capabilities/tiktok_link_resolver.dart';
import 'package:live_sites/src/platforms/tiktok/capabilities/tiktok_play_lease_lookup.dart';
import 'package:live_sites/src/platforms/tiktok/capabilities/tiktok_playback_provider.dart';
import 'package:live_sites/src/platforms/tiktok/capabilities/tiktok_room_provider.dart';
import 'package:live_sites/src/platforms/tiktok/capabilities/tiktok_room_refresh.dart';
import 'package:live_sites/src/platforms/tiktok/capabilities/tiktok_search_provider.dart';
import 'package:live_sites/src/platforms/tiktok/capabilities/tiktok_status_check.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_failure.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_link.dart';
import 'package:live_sites/src/platforms/tiktok/parsers/tiktok_room_parser.dart';
import 'package:live_sites/src/platforms/tiktok/tiktok_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The TikTok LIVE adapter (parsing in `parsers/`, links in
/// [TiktokLink]): manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2).
///
/// Link-only, as TikTok has no anonymous directory or search: the directory
/// is always an empty last page, and search looks up the one user a
/// username, `@username` or link names. A room is a user: its id is the
/// lower-case username, never the numeric LIVE room id, which changes with
/// every broadcast. Anonymous: no cookie, no account, and no chat (the
/// reference adapter ships no danmaku for TikTok, so no chat session is
/// ever offered). Requests are:
/// - room entry reads the user's LIVE (`api-live/user/room`) with its
///   streams; the card keeps them for playback until the next entry;
/// - search reads the same answer without its streams; a `share/live` link
///   asks `webcast/room/info` for its owner first; a short link typed into
///   search is followed by the transport and the username read out of the
///   page it lands on;
/// - playback uses the streams the entry brought.
///
/// Failures are [TiktokFailure]s; nothing is disguised as an offline room.
final class TiktokSite implements LiveSite {
  /// Creates the adapter over [http]. [preferH264] reads the "prefer H.264"
  /// setting (on by default) at each call: on, a room's H.264 qualities come
  /// before its H.265 ones, so the default is H.264; off, best tier first.
  /// [now] (when an answer arrived, the start of its URLs' lifetime) is
  /// injectable for tests.
  TiktokSite({required this.http, bool Function()? preferH264, DateTime Function()? now})
    : _preferH264 = preferH264 ?? _on,
      _now = now ?? DateTime.now;

  /// Transport.
  final TiktokHttp http;

  final bool Function() _preferH264;
  final DateTime Function() _now;

  static bool _on() => true;

  /// The stream data of the user whose room was entered last, by username:
  /// the streams the capabilities hand out until the next entry.
  final Map<String, TiktokRoomData> _streams = {};

  /// Rooms whose stream data the adapter keeps.
  static const int _streamCacheLimit = 64;

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => tiktokManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Rooms ---------------------------------------------------------------------

  /// The username the room id [roomId] names (trimmed and lower-cased);
  /// anything else is not-found without a request.
  String _username(String roomId) =>
      TiktokLink.normalizeUsername(roomId) ??
      (throw TiktokFailure(TiktokFailureKind.notFound, 'not a TikTok username: $roomId'));

  /// The user's LIVE as the room [username], with its streams when
  /// [includeMedia].
  Future<LiveRoom> _room(String username, {required bool includeMedia}) async {
    final response = await http.get(
      TiktokEndpoints.userRoomUrl(username),
      headers: TiktokEndpoints.requestHeaders(username: username),
    );
    return TiktokRoomParser.room(
      response.text,
      username: username,
      includeMedia: includeMedia,
      issuedAt: _now(),
      status: response.status,
    );
  }

  /// Room entry: one request, with the streams in the room's runtime handle.
  /// A live room without a stream is still returned; playing it says why it
  /// cannot.
  Future<LiveRoom> detail(String roomId) async {
    final username = _username(roomId);
    final room = await _room(username, includeMedia: true);
    final data = room.runtime.streamHandle;
    if (data is TiktokRoomData) {
      _streams[username] = data;
      while (_streams.length > _streamCacheLimit) {
        _streams.remove(_streams.keys.first);
      }
    }
    return room;
  }

  /// A refresh: the room page without media, as the follow lists ask.
  Future<LiveRoom> refreshRoom(String roomId) => _room(_username(roomId), includeMedia: false);

  /// The owner of LIVE room [liveRoomId] (`webcast/room/info`).
  Future<String> owner(String liveRoomId) async {
    final response = await http.get(TiktokEndpoints.roomInfoUrl(liveRoomId), headers: TiktokEndpoints.requestHeaders());
    return TiktokRoomParser.owner(response.text, liveRoomId: liveRoomId, status: response.status);
  }

  /// The username the page a short link [start] lands on (the transport
  /// follows the redirect chain itself); null when the landed page names no
  /// user of this site.
  Future<String?> shortLinkUsername(Uri start) async {
    final response = await http.get(start, headers: {'user-agent': TiktokEndpoints.userAgent});
    return TiktokRoomParser.usernameInPage(response.text, status: response.status);
  }

  // Search --------------------------------------------------------------------

  /// The one user [keyword] names, on page 1 only: a username with or
  /// without `@` or a user link reads the user's LIVE (one request); a
  /// `share/live` link asks for its owner first (two); a short link is
  /// followed by the transport and read off the page it lands on. Other
  /// keywords, later pages and a page size below 1 give nothing without a
  /// request. A user, LIVE room or short link the site does not know gives
  /// nothing; every other failure is thrown. The card carries no streams.
  Future<({List<LiveRoom> rooms, bool? hasMore})> search(String keyword, {int page = 1, int pageSize = 30}) async {
    if (page != 1 || pageSize < 1) return (rooms: const <LiveRoom>[], hasMore: null);
    final short = TiktokLink.shortLink(keyword);
    final link = short == null ? TiktokLink.lookup(keyword) : null;
    if (short == null && link == null) return (rooms: const <LiveRoom>[], hasMore: null);
    try {
      final username = short != null
          ? await shortLinkUsername(short)
          : switch (link!.kind) {
              TiktokLinkKind.username => link.id,
              TiktokLinkKind.liveRoom => await owner(link.id),
            };
      if (username == null) return (rooms: const <LiveRoom>[], hasMore: null);
      return (rooms: [await _room(username, includeMedia: false)], hasMore: null);
    } on TiktokFailure catch (failure) {
      if (failure.kind != TiktokFailureKind.notFound) rethrow;
      return (rooms: const <LiveRoom>[], hasMore: null);
    }
  }

  // Streams -------------------------------------------------------------------

  /// The stream data of [roomId]: the one its room entry brought, or a fresh
  /// entry — the capabilities are asked by room id alone. A room known not
  /// to play (offline, restricted, without a readable stream) says why,
  /// without a request.
  Future<TiktokRoomData> _playable(String roomId) async {
    final username = _username(roomId);
    final known = _streams[username];
    if (known == null) {
      await detail(username);
      return _streams[username]!;
    }
    final blocked = TiktokRoomParser.unplayable(known);
    if (blocked != null) throw blocked;
    return known;
  }

  /// The qualities of the streams [roomId]'s entry brought (one per tier and
  /// codec, H.264 first while "prefer H.264" is on); a room without an entry
  /// yet is entered first.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async =>
      TiktokRoomParser.qualities(await _playable(roomId), preferH264: _preferH264());

  /// The lines of [quality] (the best one under the current preference when
  /// it is null): FLV then HLS, with the media headers and the leases.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality}) async =>
      TiktokRoomParser.lines(await _playable(roomId), quality, preferH264: _preferH264());

  // Directory -----------------------------------------------------------------

  /// The directory: always an empty last page — no public directory is
  /// reachable anonymously. A page below 1 is a caller error. Nothing is
  /// requested.
  Future<({List<LiveRoom> rooms, bool hasMore})> directory(int page) async {
    if (page < 1) {
      throw TiktokFailure(TiktokFailureKind.invalidArgument, 'page $page is below 1');
    }
    return (rooms: const <LiveRoom>[], hasMore: false);
  }

  // Capability wiring ---------------------------------------------------------

  TiktokRoomProvider? _roomProvider;
  TiktokDiscoveryProvider? _discovery;
  TiktokSearchProvider? _search;
  TiktokPlaybackProvider? _playback;
  TiktokPlayLeaseLookup? _lease;
  TiktokLinkResolver? _link;
  TiktokRoomRefresh? _refresh;
  TiktokStatusCheck? _status;

  /// The capability of type [T], or null when TikTok does not support it
  /// (ARCHITECTURE.md §4.1): no chat (the reference adapter ships no
  /// danmaku), no areas, no hot list, no anchor index, no web search.
  /// Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _roomProvider ??= TiktokRoomProvider(site: this);
    final discovery = _discovery ??= TiktokDiscoveryProvider(site: this);
    final search = _search ??= TiktokSearchProvider(site: this);
    final playback = _playback ??= TiktokPlaybackProvider(site: this);
    final lease = _lease ??= TiktokPlayLeaseLookup(now: _now);
    final link = _link ??= TiktokLinkResolver(site: this);
    final refresh = _refresh ??= TiktokRoomRefresh(site: this);
    final status = _status ??= TiktokStatusCheck(refresh: refresh);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LivePlayLeaseLookup) => lease as T,
      const (LiveLinkResolver) => link as T,
      const (LiveDanmakuProvider) => null,
      const (LiveAreaProvider) => null,
      const (LiveRoomRefresh) => refresh as T,
      const (LiveStatusCheck) => status as T,
      _ => null,
    };
  }
}
