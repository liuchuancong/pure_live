import 'dart:async';

// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_link_resolver.dart';
import 'package:live_sites/src/capabilities/live_play_recovery.dart';
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
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/picarto/api/picarto_endpoints.dart';
import 'package:live_sites/src/platforms/picarto/api/picarto_http.dart';
import 'package:live_sites/src/platforms/picarto/capabilities/picarto_area_provider.dart';
import 'package:live_sites/src/platforms/picarto/capabilities/picarto_discovery_provider.dart';
import 'package:live_sites/src/platforms/picarto/capabilities/picarto_link_resolver.dart';
import 'package:live_sites/src/platforms/picarto/capabilities/picarto_play_recovery.dart';
import 'package:live_sites/src/platforms/picarto/capabilities/picarto_playback_provider.dart';
import 'package:live_sites/src/platforms/picarto/capabilities/picarto_room_provider.dart';
import 'package:live_sites/src/platforms/picarto/capabilities/picarto_room_refresh.dart';
import 'package:live_sites/src/platforms/picarto/capabilities/picarto_search_provider.dart';
import 'package:live_sites/src/platforms/picarto/capabilities/picarto_status_check.dart';
import 'package:live_sites/src/platforms/picarto/danmaku/picarto_danmaku_codec.dart';
import 'package:live_sites/src/platforms/picarto/danmaku/picarto_danmaku_session.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_failure.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_link.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_room_parser.dart';
import 'package:live_sites/src/platforms/picarto/picarto_manifest.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The Picarto.TV adapter (parsing in `parsers/`, the chat in `danmaku/`):
/// manifest + capability discovery + lifecycle (ARCHITECTURE.md §7.2).
///
/// Anonymous: no cookie, no account; every request carries
/// [PicartoEndpoints.headers] and goes as `picarto`. The requests are the
/// website's:
/// - the catalog is one category whose first area is the public directory,
///   read from `api/languages-categories`;
/// - the recommendations, the public directory and a category's rooms are
///   `api/explore` pages of [PicartoEndpoints.pageSize] (sizes clamped to
///   1–60), live non-adult channels by viewers;
/// - search is `api/search`'s channel profiles (offline ones too), pages
///   ending with an empty one;
/// - room entry reads the detail and, when live, the HLS master playlist on
///   the edge the load balancer chose, and at the same time the public API's
///   start of the broadcast on air;
/// - the chat asks the GraphQL API for an anonymous token, then joins the
///   channel's socket.
///
/// Room ids are the platform's spelling of the channel name (a room asked
/// for as `thebaker` is `TheBaker`), as the reference's follows stored them;
/// rooms compare ignoring case. Failures are [PicartoFailure]s; nothing is
/// disguised as an offline room.
final class PicartoSite implements LiveSite {
  /// Creates the adapter over [http]. [connect] makes the chat's socket
  /// (default [webSocketConnect]).
  PicartoSite({required this.http, this.connect = webSocketConnect});

  /// Transport.
  final PicartoHttp http;

  /// How the chat's socket is connected.
  final SocketConnector connect;

  /// The stream data of the channel whose room was entered last, by room id
  /// (the platform's spelling): the qualities and lines the capabilities
  /// hand out until the next entry.
  final Map<String, PicartoStreamData> _streams = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => picartoManifest;

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

  /// The catalog's areas: the public directory first, then the platform's
  /// categories, all under the one category.
  Future<List<LiveArea>> areas() async {
    final response = await http.get(PicartoEndpoints.categoriesUrl());
    return PicartoRoomParser.areas(response.text, status: response.status);
  }

  /// Page [page] of [pageSize] rows of the public directory, or of category
  /// [categoryId] when given ([PicartoRoomParser.categoryIdOf] names it).
  /// Live channels by viewers, adult content excluded; a page below 1 asked
  /// as 1, [pageSize] clamped to 1–60, as the reference asked.
  Future<({List<LiveRoom> rooms, bool hasMore})> directory(int page, int pageSize, {int? categoryId}) async {
    final number = page < 1 ? 1 : page;
    final size = pageSize.clamp(1, PicartoEndpoints.maxPageSize);
    final response = await http.get(PicartoEndpoints.exploreUrl(page: number, pageSize: size, categoryId: categoryId));
    return PicartoRoomParser.directoryPage(
      response.text,
      page: number,
      pageSize: size,
      categoryId: categoryId,
      status: response.status,
    );
  }

  // Search --------------------------------------------------------------------

  /// Channel profiles matching [keyword], live and offline; [pageSize] is
  /// sent clamped to 1–60 and the keyword's first
  /// [PicartoEndpoints.maxKeywordLength] characters. A blank keyword gives
  /// nothing without a request; a page that read nothing ends the keyword.
  Future<({List<LiveRoom> rooms, bool hasMore})> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final text = keyword.trim();
    if (text.isEmpty) return (rooms: const <LiveRoom>[], hasMore: false);
    final number = page < 1 ? 1 : page;
    final size = pageSize.clamp(1, PicartoEndpoints.maxPageSize);
    final cut = text.length > PicartoEndpoints.maxKeywordLength
        ? text.substring(0, PicartoEndpoints.maxKeywordLength)
        : text;
    final response = await http.get(PicartoEndpoints.searchUrl(keyword: cut, page: number, pageSize: size));
    final rooms = PicartoRoomParser.searchRooms(response.text, pageSize: size, status: response.status);
    return (rooms: rooms, hasMore: rooms.isNotEmpty);
  }

  // Rooms ---------------------------------------------------------------------

  /// `api/channel/detail/<name>`; a room id that is no channel name is
  /// not-found without a request.
  Future<PicartoChannel> channelDetail(String roomId, {bool stream = true}) async {
    final id = roomId.trim();
    if (!PicartoEndpoints.isChannelName(id)) {
      throw PicartoFailure(PicartoFailureKind.notFound, 'room id "$id" is not a Picarto channel name');
    }
    final response = await http.get(PicartoEndpoints.channelDetailUrl(id));
    return PicartoRoomParser.roomDetail(response.text, requestedId: id, status: response.status, stream: stream);
  }

  /// Room entry: the detail and, when live, the master playlist's qualities
  /// in [PicartoStreamData], and the start of the broadcast on air; the room
  /// carries the stream data and the chat's arguments as its handles. A
  /// private channel is entered without a stream (it needs the streamer's
  /// private key).
  Future<LiveRoom> detail(String roomId) async {
    final channel = await channelDetail(roomId);
    final since = channel.room.broadcast.isLiveNow ? _liveSince(channel.name) : Future<DateTime?>.value();
    final master = channel.master;
    PicartoStreamData? data;
    if (master != null) {
      final response = await http.get(master);
      data = PicartoStreamData(
        name: channel.name,
        channelId: channel.channelId,
        master: master,
        qualities: PicartoRoomParser.qualities(response.text, master: master, status: response.status),
        requestedId: channel.requestedId,
      );
    }
    // A channel that just went offline drops the stream its entry held.
    if (data == null) {
      _streams.remove(channel.name);
    } else {
      _streams[channel.name] = data;
    }
    final startedAt = await since;
    return channel.room.rebuild(
      (b) => b
        ..broadcast.replace(channel.room.broadcast.rebuild((r) => r..startedAt = startedAt))
        ..runtime = RoomRuntime.of(
          streamHandle: data,
          danmakuHandle: PicartoDanmakuArgs(channelName: channel.name, channelId: channel.channelId),
        ).toBuilder(),
    );
  }

  /// The start of [name]'s broadcast on air
  /// ([PicartoRoomParser.liveSince]), or null when the public API fails or
  /// does not say. Never completes with an exception, so it can run beside
  /// the master playlist.
  Future<DateTime?> _liveSince(String name) async {
    try {
      final response = await http.get(PicartoEndpoints.channelNameUrl(name));
      return PicartoRoomParser.liveSince(response.text, name: name, status: response.status);
    } on Object {
      // A failure of the site, or a cancelled transport: the room stands
      // without the start.
      return null;
    }
  }

  // Streams -------------------------------------------------------------------

  /// The stream data of [roomId]: the one its room entry brought, or a fresh
  /// entry — the capabilities are asked by room id alone. A channel the
  /// platform called offline has no stream without a new request; a private
  /// one says it needs the streamer's key.
  Future<PicartoStreamData> _stream(String roomId, {bool fresh = false}) async {
    final id = roomId.trim();
    final held = fresh ? null : _streams[id];
    if (held != null) return held;
    final room = await detail(id);
    final data = room.runtime.streamHandle;
    if (data is PicartoStreamData) return data;
    if (room.broadcast.isLiveNow && room.broadcast.effectiveRestriction == LiveRestriction.private) {
      throw PicartoFailure(
        PicartoFailureKind.streamUnavailable,
        "channel ${room.roomId} is private: it needs the streamer's private key",
      );
    }
    throw PicartoFailure(
      PicartoFailureKind.streamUnavailable,
      'channel/detail: ${room.roomId} is ${room.broadcast.effectiveLiveStatus.name}',
    );
  }

  /// The qualities [roomId] offers now (a room entered earlier needs no new
  /// request). A channel that is off the air or private says why.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async => (await _stream(roomId)).options;

  /// The lines of [quality] (the best quality when it is null): one per
  /// variant URL of the profile, on the edge the entry's playlist named. A
  /// quality the playlist no longer has — the streamer changed the profile
  /// since the entry — plays the best one instead, as recovery did.
  Future<List<LivePlayLine>> linesOf(String roomId, {LivePlayQuality? quality, bool fresh = false}) async {
    final data = await _stream(roomId, fresh: fresh);
    final wanted = quality?.qualityId;
    final current = (wanted == null ? null : data.byId(wanted)) ?? data.qualities.firstOrNull;
    if (current == null) {
      throw PicartoFailure(PicartoFailureKind.streamUnavailable, 'master playlist: no quality $wanted');
    }
    return PicartoRoomParser.lines(current, master: data.master);
  }

  // Links ---------------------------------------------------------------------

  /// The channel page of the channel [uri] names, canonicalized without a
  /// request; null when [uri] is no Picarto channel page.
  Uri? canonicalRoomUrl(Uri uri) {
    final name = PicartoLink.channelFromUrl(uri);
    return name == null ? null : Uri.parse(PicartoEndpoints.roomPageUrl(name));
  }

  /// Whether [uri] is on one of Picarto's hosts (so a link there that names
  /// no channel is this site's, not a foreign one).
  static bool ownsHost(Uri uri) => PicartoLink.ownsHost(uri.host.toLowerCase());

  // Capability wiring ---------------------------------------------------------

  PicartoRoomProvider? _room;
  PicartoAreaProvider? _area;
  PicartoDiscoveryProvider? _discovery;
  PicartoSearchProvider? _search;
  PicartoPlaybackProvider? _playback;
  PicartoDanmakuProvider? _danmaku;
  PicartoLinkResolver? _link;
  PicartoRoomRefresh? _refresh;
  PicartoStatusCheck? _status;
  PicartoPlayRecovery? _recovery;

  /// The capability of type [T], or null when Picarto does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= PicartoRoomProvider(site: this);
    final area = _area ??= PicartoAreaProvider(site: this);
    final discovery = _discovery ??= PicartoDiscoveryProvider(site: this);
    final search = _search ??= PicartoSearchProvider(site: this);
    final playback = _playback ??= PicartoPlaybackProvider(site: this);
    final danmaku = _danmaku ??= PicartoDanmakuProvider(site: this);
    final link = _link ??= PicartoLinkResolver(site: this);
    final refresh = _refresh ??= PicartoRoomRefresh(site: this);
    final status = _status ??= PicartoStatusCheck(refresh: refresh);
    final recovery = _recovery ??= PicartoPlayRecovery(playback: playback);
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
      const (LivePlayRecovery) => recovery as T,
      _ => null,
    };
  }
}
