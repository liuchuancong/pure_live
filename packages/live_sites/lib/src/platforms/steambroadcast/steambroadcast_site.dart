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
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/play/live_play_line/live_play_line.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/steambroadcast/api/steambroadcast_endpoints.dart';
import 'package:live_sites/src/platforms/steambroadcast/api/steambroadcast_http.dart';
import 'package:live_sites/src/platforms/steambroadcast/capabilities/steambroadcast_area_provider.dart';
import 'package:live_sites/src/platforms/steambroadcast/capabilities/steambroadcast_discovery_provider.dart';
import 'package:live_sites/src/platforms/steambroadcast/capabilities/steambroadcast_link_resolver.dart';
import 'package:live_sites/src/platforms/steambroadcast/capabilities/steambroadcast_playback_provider.dart';
import 'package:live_sites/src/platforms/steambroadcast/capabilities/steambroadcast_room_provider.dart';
import 'package:live_sites/src/platforms/steambroadcast/capabilities/steambroadcast_search_provider.dart';
import 'package:live_sites/src/platforms/steambroadcast/danmaku/steambroadcast_danmaku_codec.dart';
import 'package:live_sites/src/platforms/steambroadcast/danmaku/steambroadcast_danmaku_session.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_failure.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_room_parser.dart';
import 'package:live_sites/src/platforms/steambroadcast/steambroadcast_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How many broadcasters the site remembers to fill room answers from (the
/// reference kept every one it listed).
const _rememberLimit = 1000;

/// The Steam Broadcast adapter (parsing in `parsers/`, the chat in
/// `danmaku/`): manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2).
///
/// Anonymous, like the reference: no cookie, no account. Every request
/// carries the headers [SteambroadcastEndpoints] builds for it and goes as
/// `steambroadcast`, so the app routes the platform through its proxy
/// setting. The requests:
/// - the catalog is one area, the trending broadcasts; its pages, the
///   recommendations and the keyword search are `allcontenthome` (ten a
///   page, HTML);
/// - a room's name and avatar are its mini profile (the watch page, the
///   reference's source of the name, when the profile fails);
/// - a search by id, watch link or profile link, and a link resolution,
///   read the refresh answers (mini profile, then `getbroadcastinfo`,
///   `getbroadcastmpd` when that fails): no master;
/// - room entry reads `getbroadcastmpd` (state, restriction, viewers,
///   master), then for a broadcast that is not offline `getbroadcastinfo`
///   (title, game, cover) and the HLS master, checked against the account
///   (its variants are the qualities);
/// - each list or room call has one [deadline].
///
/// Like the reference, the site remembers the broadcasters it listed and
/// fills a room answer's missing name, title, game, cover, avatar and (while
/// live) viewers from them.
///
/// Rooms are identified by the broadcaster's 64-bit Steam id; watch and
/// profile links are accepted as room ids, custom addresses resolve with one
/// request. Failures are [SteambroadcastFailure]s; nothing is disguised as an
/// offline room, and a media problem never fails the room itself: it is
/// reported when the stream is asked for.
final class SteambroadcastSite implements LiveSite {
  /// Creates the adapter over [http]. [deadline] bounds one list call, or
  /// one room call with all its requests (the reference: 25 s).
  SteambroadcastSite({required this.http, this.deadline = const Duration(seconds: 25)});

  /// Transport.
  final SteambroadcastHttp http;

  /// Longest list or room call.
  final Duration deadline;

  /// The last broadcast seen of each broadcaster, oldest first.
  final Map<String, SteambroadcastBroadcast> _known = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => steambroadcastManifest;

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

  /// [work] under its own cancellation, ended when [deadline] passes: the
  /// deadline is a network failure, a caller's own cancellation rethrows.
  Future<T> _scoped<T>(Future<T> Function(CancelToken token) work) async {
    final token = CancelToken();
    var expired = false;
    final timer = Timer(deadline, () {
      expired = true;
      token.cancel();
    });
    try {
      return await work(token);
    } on CancelledFailure catch (failure) {
      if (!expired) rethrow;
      throw SteambroadcastFailure(
        SteambroadcastFailureKind.network,
        'no answer within ${deadline.inSeconds} s',
        cause: failure,
      );
    } finally {
      timer.cancel();
    }
  }

  /// Remembers [broadcast] as the latest of its broadcaster.
  void _remember(SteambroadcastBroadcast broadcast) {
    _known
      ..remove(broadcast.steamId)
      ..[broadcast.steamId] = broadcast;
    if (_known.length > _rememberLimit) _known.remove(_known.keys.first);
  }

  // Directory -----------------------------------------------------------------

  /// Page [page] of the trending broadcasts; its cards are remembered. A
  /// page past [SteambroadcastEndpoints.maxPage] is a caller error, without
  /// a request.
  Future<SteambroadcastPage> directory(int page) {
    if (page > SteambroadcastEndpoints.maxPage) {
      throw SteambroadcastFailure(
        SteambroadcastFailureKind.invalidArgument,
        'page $page is past ${SteambroadcastEndpoints.maxPage}',
      );
    }
    return _scoped((token) async {
      final response = await http.get(
        SteambroadcastEndpoints.directoryUrl(page),
        headers: SteambroadcastEndpoints.directoryHeaders,
        cancel: token,
      );
      final result = SteambroadcastRoomParser.directory(response.text, page: page, status: response.status);
      result.broadcasts.forEach(_remember);
      return result;
    });
  }

  /// Page [page] (ten broadcasts) of the trending broadcasts, as rooms.
  /// A page below 1 is empty without a request.
  Future<({List<LiveRoom> rooms, bool hasMore})> rooms(int page) async {
    if (page < 1) return (rooms: const <LiveRoom>[], hasMore: false);
    final result = await directory(page);
    return (
      rooms: [for (final broadcast in result.broadcasts) SteambroadcastRoomParser.room(broadcast)],
      hasMore: result.hasMore,
    );
  }

  /// The first [pageSize] (at most 60) cards of directory page [page]; a
  /// page or size below 1 gives nothing without a request.
  Future<({List<LiveRoom> rooms, bool hasMore})> recommend(int page, int pageSize) async {
    if (page < 1 || pageSize < 1) return (rooms: const <LiveRoom>[], hasMore: false);
    final result = await directory(page);
    final cut = pageSize.clamp(1, SteambroadcastEndpoints.maxRecommendSize);
    return (
      rooms: [for (final broadcast in result.broadcasts.take(cut)) SteambroadcastRoomParser.room(broadcast)],
      hasMore: result.hasMore,
    );
  }

  /// Rooms of the one area: the trending broadcasts.
  Future<({List<LiveRoom> rooms, bool hasMore})> areaRooms(String areaId, int page) {
    if (!SteambroadcastRoomParser.isArea(areaId)) {
      throw SteambroadcastFailure(
        SteambroadcastFailureKind.invalidArgument,
        'area "$areaId" is not the trending Steam broadcasts',
      );
    }
    return rooms(page);
  }

  // Search --------------------------------------------------------------------

  /// The search (Steam has no anonymous broadcast search): a Steam id, a
  /// watch link or a profile link is the account's room (the refresh's two
  /// requests, first page only); a custom address
  /// `steamcommunity.com/id/<name>` is resolved first (one more request);
  /// an account without a page is no result. Any other keyword filters
  /// directory page [page] by id, name, title and game (case ignored). A
  /// blank keyword, a page below 1 or a page size outside 1–100 gives
  /// nothing without a request.
  Future<({List<LiveRoom> rooms, bool? hasMore})> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final raw = keyword.trim();
    if (raw.isEmpty || page < 1 || pageSize < 1 || pageSize > SteambroadcastEndpoints.maxSearchSize) {
      return (rooms: const <LiveRoom>[], hasMore: null);
    }
    final steamId = SteambroadcastEndpoints.steamIdOf(raw);
    final vanity = SteambroadcastEndpoints.vanityOf(raw);
    if (steamId != null || vanity != null) {
      if (page > 1) return (rooms: const <LiveRoom>[], hasMore: null);
      try {
        return await _scoped<({List<LiveRoom> rooms, bool? hasMore})>((token) async {
          final id = steamId ?? await _resolveVanity(vanity!, token);
          if (id == null) return (rooms: const <LiveRoom>[], hasMore: null);
          return (rooms: [await detail(id, media: false)], hasMore: null);
        });
      } on SteambroadcastFailure catch (failure) {
        if (failure.kind != SteambroadcastFailureKind.notFound) rethrow;
        return (rooms: const <LiveRoom>[], hasMore: null);
      }
    }
    final result = await directory(page);
    return (
      rooms: [
        for (final broadcast in SteambroadcastRoomParser.filter(result.broadcasts, raw.toLowerCase()).take(pageSize))
          SteambroadcastRoomParser.room(broadcast),
      ],
      hasMore: null,
    );
  }

  /// The Steam id at the custom address [vanity] (its profile XML), or null
  /// when there is no such profile.
  Future<String?> resolveVanity(String vanity) => _scoped((token) => _resolveVanity(vanity, token));

  Future<String?> _resolveVanity(String vanity, CancelToken token) async {
    final answer = await http.get(
      SteambroadcastEndpoints.vanityUrl(vanity),
      headers: SteambroadcastEndpoints.xmlHeaders,
      cancel: token,
    );
    return SteambroadcastRoomParser.steamIdOfProfileXml(answer.text, status: answer.status);
  }

  // Rooms ---------------------------------------------------------------------

  /// The broadcaster's name and avatar: the mini profile, or when it fails
  /// the watch page's name (its failures are the room's; a page without a
  /// broadcast config is not-found).
  Future<SteambroadcastProfile> _profile(String steamId, CancelToken cancel) async {
    try {
      final answer = await http.get(
        SteambroadcastEndpoints.profileUrl(steamId),
        headers: SteambroadcastEndpoints.roomHeaders(steamId, json: true),
        cancel: cancel,
      );
      return SteambroadcastRoomParser.profile(answer.text, steamId: steamId, status: answer.status);
    } on SteambroadcastFailure {
      final watch = await http.get(
        SteambroadcastEndpoints.watchUrl(steamId),
        headers: SteambroadcastEndpoints.roomHeaders(steamId),
        cancel: cancel,
      );
      return (
        name: SteambroadcastRoomParser.broadcaster(watch.text, steamId: steamId, status: watch.status),
        avatar: '',
      );
    }
  }

  /// `getbroadcastmpd` of [steamId] with [profile]'s name and avatar.
  Future<SteambroadcastBroadcast> _mpd(String steamId, SteambroadcastProfile profile, CancelToken cancel) async {
    final answer = await http.get(
      SteambroadcastEndpoints.mpdUrl(steamId),
      headers: SteambroadcastEndpoints.roomHeaders(steamId, json: true),
      cancel: cancel,
    );
    return SteambroadcastRoomParser.broadcast(answer.text, steamId: steamId, profile: profile, status: answer.status);
  }

  /// `getbroadcastinfo` of [steamId] with [profile]'s name and avatar.
  Future<SteambroadcastBroadcast> _info(String steamId, SteambroadcastProfile profile, CancelToken cancel) async {
    final answer = await http.get(
      SteambroadcastEndpoints.infoUrl(steamId),
      headers: SteambroadcastEndpoints.roomHeaders(steamId, json: true),
      cancel: cancel,
    );
    return SteambroadcastRoomParser.info(answer.text, steamId: steamId, profile: profile, status: answer.status);
  }

  /// [broadcast] with its HLS master loaded and checked against the account,
  /// and its variants read. Whatever goes wrong with the master becomes the
  /// broadcast's media error.
  Future<SteambroadcastBroadcast> _withMaster(SteambroadcastBroadcast broadcast, CancelToken cancel) async {
    final master = broadcast.master;
    if (master == null || broadcast.mediaError != null) return broadcast;
    final steamId = broadcast.steamId;
    try {
      final playlist = await http.get(master, headers: SteambroadcastEndpoints.mediaHeaders(steamId), cancel: cancel);
      final codec = SteambroadcastRoomParser.checkMaster(
        playlist.text,
        master: master,
        steamId: steamId,
        status: playlist.status,
      );
      return broadcast.withMaster(
        codec: codec,
        variants: SteambroadcastRoomParser.variants(playlist.text, master: master),
      );
    } on SteambroadcastFailure catch (error) {
      return broadcast.withMaster(mediaError: error);
    }
  }

  /// The room's answers. The name and avatar come from [_profile]. Without
  /// [media] (a search hit): `getbroadcastinfo`, or `getbroadcastmpd` when
  /// that fails. With [media] (room entry): `getbroadcastmpd` (the state and
  /// restriction), then unless it is offline or the account may not
  /// broadcast `getbroadcastinfo` (title, game, cover; its failure is
  /// ignored) and the checked master.
  Future<SteambroadcastBroadcast> _read(String steamId, {required bool media, required CancelToken cancel}) async {
    final profile = await _profile(steamId, cancel);
    if (!media) {
      try {
        return await _info(steamId, profile, cancel);
      } on SteambroadcastFailure {
        return await _mpd(steamId, profile, cancel);
      }
    }
    var broadcast = await _mpd(steamId, profile, cancel);
    if (broadcast.state != SteambroadcastState.offline && broadcast.state != SteambroadcastState.accountRestricted) {
      try {
        broadcast = broadcast.withInfo(await _info(steamId, profile, cancel));
      } on SteambroadcastFailure {
        // The title, game and cover stay those of getbroadcastmpd and the
        // remembered card.
      }
    }
    return await _withMaster(broadcast, cancel);
  }

  /// [broadcast] filled from the last one remembered of the broadcaster,
  /// then remembered itself, as a room.
  LiveRoom _finish(SteambroadcastBroadcast broadcast, {bool danmaku = false}) {
    final known = _known[broadcast.steamId];
    final filled = known == null ? broadcast : broadcast.enrich(known);
    _remember(filled);
    final room = SteambroadcastRoomParser.room(filled, data: SteambroadcastRoomParser.roomData(filled));
    if (!danmaku) return room;
    return room.rebuild(
      (b) => b
        ..runtime = RoomRuntime.of(
          streamHandle: room.runtime.streamHandle,
          danmakuHandle: SteambroadcastDanmakuArgs(filled.steamId, broadcastId: filled.broadcastId),
        ).toBuilder(),
    );
  }

  /// The room of [roomId] within one [deadline]: without [media] the
  /// refresh's two requests (a search hit); with it room entry — its
  /// profile, `getbroadcastmpd`, and unless offline `getbroadcastinfo` and
  /// the checked HLS master, with the chat's arguments.
  Future<LiveRoom> detail(String roomId, {bool media = true}) async {
    final steamId = _steamId(roomId);
    final broadcast = await _scoped((token) => _read(steamId, media: media, cancel: token));
    return _finish(broadcast, danmaku: media);
  }

  /// [roomId] as a Steam id (a bare id, a watch link or a profile link);
  /// anything else is not-found without a request.
  String _steamId(String roomId) {
    final steamId = SteambroadcastEndpoints.steamIdOf(roomId);
    if (steamId == null) {
      throw SteambroadcastFailure(SteambroadcastFailureKind.notFound, 'room id "${roomId.trim()}" is not a Steam id');
    }
    return steamId;
  }

  // Streams -------------------------------------------------------------------

  /// The room data of [roomId]: the one its room entry brought, or a fresh
  /// entry — the playback capability is asked by room id alone. A kept
  /// answer that cannot be played says why, without a request.
  Future<SteambroadcastRoomData> _playable(String roomId) async {
    final steamId = _steamId(roomId);
    final known = _known[steamId];
    if (known != null && known.masterChecked) {
      final data = SteambroadcastRoomParser.roomData(known);
      final error = data.streamError;
      if (error == null) return data;
      throw error;
    }
    final fresh = await detail(steamId);
    final data = fresh.runtime.streamHandle;
    if (data is! SteambroadcastRoomData) {
      throw const SteambroadcastFailure(
        SteambroadcastFailureKind.streamUnavailable,
        'the room carries no stream answer',
      );
    }
    final error = data.streamError;
    if (error != null) throw error;
    return data;
  }

  /// The qualities [roomId] offers now: the adaptive master first, then one
  /// per variant of the checked master when it has several.
  Future<List<LivePlayQuality>> qualitiesOf(String roomId) async => (await _playable(roomId)).qualities;

  /// The one line of [roomId] at [quality] (the adaptive quality when it is
  /// null): the checked master, HLS, its codec, no headers and no lease.
  Future<List<LivePlayLine>> linesOf(String roomId, LivePlayQuality? quality) async {
    final data = await _playable(roomId);
    final wanted = quality?.qualityId ?? SteambroadcastEndpoints.qualityId;
    if (wanted != SteambroadcastEndpoints.qualityId && !SteambroadcastRoomParser.isVariantId(wanted)) {
      throw SteambroadcastFailure(SteambroadcastFailureKind.streamUnavailable, 'quality $wanted is not offered');
    }
    return [SteambroadcastRoomParser.line(data, wanted)];
  }

  // Capability wiring ---------------------------------------------------------

  SteambroadcastRoomProvider? _room;
  SteambroadcastAreaProvider? _area;
  SteambroadcastDiscoveryProvider? _discovery;
  SteambroadcastSearchProvider? _search;
  SteambroadcastPlaybackProvider? _playback;
  SteambroadcastDanmakuProvider? _danmaku;
  SteambroadcastLinkResolver? _link;

  /// The capability of type [T], or null when Steam Broadcast does not
  /// support it (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= SteambroadcastRoomProvider(site: this);
    final area = _area ??= SteambroadcastAreaProvider(site: this);
    final discovery = _discovery ??= SteambroadcastDiscoveryProvider(site: this);
    final search = _search ??= SteambroadcastSearchProvider(site: this);
    final playback = _playback ??= SteambroadcastPlaybackProvider(site: this);
    final danmaku = _danmaku ??= SteambroadcastDanmakuProvider(site: this);
    final link = _link ??= SteambroadcastLinkResolver(site: this);
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
