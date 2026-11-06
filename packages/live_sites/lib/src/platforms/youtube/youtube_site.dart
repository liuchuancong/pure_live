// Capability discovery maps a type to its instance by design; a type switch
// is the contract here (ARCHITECTURE.md §4.1).
// ignore_for_file: switch_on_type

import 'dart:convert';

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
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/youtube/api/youtube_endpoints.dart';
import 'package:live_sites/src/platforms/youtube/api/youtube_http.dart';
import 'package:live_sites/src/platforms/youtube/capabilities/youtube_discovery_provider.dart';
import 'package:live_sites/src/platforms/youtube/capabilities/youtube_link_resolver.dart';
import 'package:live_sites/src/platforms/youtube/capabilities/youtube_play_lease_lookup.dart';
import 'package:live_sites/src/platforms/youtube/capabilities/youtube_playback_provider.dart';
import 'package:live_sites/src/platforms/youtube/capabilities/youtube_room_provider.dart';
import 'package:live_sites/src/platforms/youtube/capabilities/youtube_room_refresh.dart';
import 'package:live_sites/src/platforms/youtube/capabilities/youtube_search_provider.dart';
import 'package:live_sites/src/platforms/youtube/capabilities/youtube_status_check.dart';
import 'package:live_sites/src/platforms/youtube/danmaku/youtube_danmaku_session.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_failure.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_room_parser.dart';
import 'package:live_sites/src/platforms/youtube/youtube_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The broadcast behind a room, apart from its identity: the [videoId] every
/// media request names, the raw streaming handles the playback provider reads
/// ([hlsManifestUrl], [dashManifestUrl], the progressive [formats]) and when the
/// player answer arrived (the origin of the signed URLs' leases). It rides in
/// the room's transient stream handle.
final class YoutubeRoomData {
  /// Wraps the stream handle.
  const YoutubeRoomData({
    required this.videoId,
    required this.issuedAt,
    this.hlsManifestUrl,
    this.dashManifestUrl,
    this.formats = const [],
  });

  /// The broadcast's video id.
  final String videoId;

  /// When the player answer arrived.
  final DateTime issuedAt;

  /// `streamingData.hlsManifestUrl`; the live primary path.
  final String? hlsManifestUrl;

  /// `streamingData.dashManifestUrl`; null for most live broadcasts.
  final String? dashManifestUrl;

  /// The progressive `streamingData.formats[]`.
  final List<Map<String, dynamic>> formats;

  @override
  String toString() => 'YoutubeRoomData($videoId)';
}

/// What the comment feed needs to follow one broadcast: the [videoId] (the
/// request's Referer), the first live-chat [continuation], the interval it
/// arrived with ([timeoutMs], a hint), the concurrent viewers the watch page
/// showed on joining ([viewers], reported once before polling), and whether the
/// chat is a replay ([isReplay], which this adapter refuses to poll).
final class YoutubeDanmakuArgs {
  /// Wraps the feed arguments.
  const YoutubeDanmakuArgs({
    required this.videoId,
    required this.continuation,
    this.timeoutMs = 0,
    this.viewers,
    this.isReplay = false,
  });

  /// The broadcast's video id.
  final String videoId;

  /// The first live-chat continuation; the poll token.
  final String continuation;

  /// The server's poll interval hint in milliseconds.
  final int timeoutMs;

  /// The concurrent viewers the room showed on joining; null when it named none.
  final int? viewers;

  /// Whether the chat is a past replay.
  final bool isReplay;

  @override
  String toString() => 'YoutubeDanmakuArgs($videoId, ${continuation.isEmpty ? 'no token' : '<token>'})';
}

/// The YouTube adapter (parsing in `parsers/`): manifest + capability discovery
/// + lifecycle (ARCHITECTURE.md §7.2).
///
/// Everything is InnerTube JSON `POST`s to `youtubei/v1/{ep}` (the player call
/// carries the public WEB API key), plus plain `GET`s of the watch page, the
/// `next` answer, the RSS feed and the HLS master. Anonymous playback goes
/// through the ANDROID client context, so no login or cookie is required:
/// requests send only the fixed `SOCS=CAI` consent cookie. Failures are
/// [YouTubeFailure]s; nothing is disguised as an offline room.
///
/// YouTube has no areas, so this adapter registers no `LiveAreaProvider` —
/// `capability<LiveAreaProvider>()` is null (see the class doc there).
final class YoutubeSite implements LiveSite {
  /// Creates the adapter over [http]. [now] (the media lease issue times) is
  /// injectable for tests.
  factory YoutubeSite({required YouTubeHttp http, DateTime Function()? now, bool Function()? allChat}) =>
      YoutubeSite._(http, now ?? DateTime.now, allChat);

  YoutubeSite._(this.http, this.now, this.allChat);

  /// Transport (the capabilities' and the comment feed's).
  final YouTubeHttp http;

  /// Injectable clock (the media leases).
  final DateTime Function() now;

  /// Whether the chat reads the "Live chat" view instead of "Top chat"
  /// (the reference's "YouTube 显示全部聊天"); null keeps Top chat.
  final bool Function()? allChat;

  /// How long the broadcast a card showed or a visit found for a channel is
  /// the one entering the channel opens (a channel may have several live
  /// broadcasts; its `/live` resolution names only one).
  static const Duration broadcastLifetime = Duration(minutes: 30);

  /// The most broadcasts remembered (the oldest is dropped past this).
  static const int _broadcastLimit = 256;

  /// The broadcast last shown for each channel, and when.
  final Map<String, ({String videoId, DateTime at})> _broadcasts = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => youtubeManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // InnerTube -----------------------------------------------------------------

  /// POSTs the InnerTube [ep] with [body] and returns the raw answer; [key]
  /// marks the player call, whose URL carries the API key. A bad status is
  /// mapped to a [YouTubeFailure].
  Future<YouTubeResponse> post(String ep, Object? body, {String? referer, bool key = false}) async {
    final response = await http.postJson(
      YoutubeEndpoints.api(ep, key: key ? YoutubeEndpoints.apiKey : null),
      json: body,
      headers: YoutubeEndpoints.apiHeaders(referer: referer),
    );
    checkStatus(response.status, ep);
    return response;
  }

  /// Maps an InnerTube HTTP status to a failure (401/403 risk control, 404
  /// not-found, 429 rate-limited, 5xx network, any other non-2xx api-changed).
  static void checkStatus(int status, String ep) {
    if (status >= 200 && status < 300) return;
    throw switch (status) {
      401 || 403 => YouTubeFailure(YoutubeFailureKind.riskControl, '$ep: HTTP $status'),
      404 => YouTubeFailure(YoutubeFailureKind.notFound, '$ep: HTTP 404'),
      429 => YouTubeFailure(YoutubeFailureKind.rateLimited, '$ep: HTTP 429'),
      >= 500 => YouTubeFailure(YoutubeFailureKind.network, '$ep: HTTP $status'),
      _ => YouTubeFailure(YoutubeFailureKind.apiChanged, '$ep: HTTP $status'),
    };
  }

  // Room ----------------------------------------------------------------------

  /// Remembers the broadcast [videoId] [channelId] showed (newest last; the
  /// oldest entry is dropped past [_broadcastLimit]).
  void _remember(String channelId, String videoId) {
    _broadcasts
      ..remove(channelId)
      ..[channelId] = (videoId: videoId, at: now());
    if (_broadcasts.length > _broadcastLimit) _broadcasts.remove(_broadcasts.keys.first);
  }

  /// The broadcast remembered for [channelId] while it is younger than
  /// [broadcastLifetime]; an older one is forgotten.
  String? _remembered(String channelId) {
    final entry = _broadcasts[channelId];
    if (entry == null) return null;
    if (now().difference(entry.at) < broadcastLifetime) return entry.videoId;
    _broadcasts.remove(channelId);
    return null;
  }

  /// Remembers the broadcast each live room of [rooms] shows, keyed by
  /// the room id (the channel): entering the channel opens the broadcast the
  /// card showed.
  void _rememberListing(List<LiveRoom> rooms) {
    for (final room in rooms) {
      if (room.broadcast.liveStatus != LiveStatus.live) continue;
      final videoId = Uri.tryParse(room.links.webUrl ?? '')?.queryParameters['v'];
      if (videoId == null || videoId.isEmpty) continue;
      _remember(room.roomId, videoId);
    }
  }

  /// The room of [id] — a video id, or a channel id whose current live
  /// broadcast is resolved first — read from a paired `player` (ANDROID) and
  /// `next` (WEB) answer; the stream and danmaku handles ride in its
  /// [RoomRuntime].
  ///
  /// A channel opens the broadcast remembered for it ([broadcastLifetime]:
  /// what a card showed or a visit last found), else the one
  /// `navigation/resolve_url` names. A remembered broadcast that proves
  /// gone, no longer live or another channel's resolves the channel again.
  Future<LiveRoom> detail(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) throw const YouTubeFailure(YoutubeFailureKind.notFound, 'empty room id');
    // A bare video id cannot hit the null branch of [_video]: that needs a
    // channel id to compare the owner against.
    if (YoutubeEndpoints.videoIdPattern.hasMatch(trimmed)) return (await _video(trimmed))!;
    final remembered = _remembered(trimmed);
    if (remembered != null) {
      try {
        final room = await _video(remembered, channelId: trimmed);
        if (room != null) return room;
      } on YouTubeFailure catch (failure) {
        if (failure.kind != YoutubeFailureKind.notFound) rethrow;
        // A remembered broadcast that is gone resolves the channel again.
      }
    }
    return (await _video(await resolveVideoId(trimmed)))!;
  }

  /// The room of [videoId] from its paired `player` and `next` answers, the
  /// stream and danmaku handles riding in its [RoomRuntime]; a live
  /// broadcast is remembered for its channel. Null when [channelId] is given
  /// and the video proves to be another channel's or no longer live — its
  /// channel names the broadcast to open instead.
  Future<LiveRoom?> _video(String videoId, {String? channelId}) async {
    final referer = YoutubeEndpoints.watchUrl(videoId);
    final player = await post('player', YoutubeEndpoints.playerBody(videoId), referer: referer, key: true);
    final next = await post('next', YoutubeEndpoints.nextBody(videoId), referer: referer);
    final parse = YoutubeRoomParser.room(player.text, next.text, requestedId: videoId);
    final owner = parse.room.anchor?.anchorId ?? '';
    if (channelId != null && owner.isNotEmpty && owner != channelId) return null;
    if (parse.room.broadcast.liveStatus != LiveStatus.live) {
      if (channelId != null) return null;
    } else if (owner.isNotEmpty) {
      _remember(owner, parse.videoId);
    }
    return parse.room.rebuild(
      (b) => b
        ..runtime = RoomRuntime.of(
          streamHandle: YoutubeRoomData(
            videoId: parse.videoId,
            issuedAt: now(),
            hlsManifestUrl: parse.hlsManifestUrl,
            dashManifestUrl: parse.dashManifestUrl,
            formats: parse.formats,
          ),
          danmakuHandle: YoutubeDanmakuArgs(
            videoId: parse.videoId,
            continuation: parse.continuation,
            timeoutMs: parse.timeoutMs,
            viewers: parse.room.audience.onlineViewers,
            isReplay: parse.isReplay,
          ),
        ).toBuilder(),
    );
  }

  /// The `/live` path of [id]: a `UC…` channel id as its `/channel/` page,
  /// anything else as the handle page.
  static String _channelLiveUrl(String id) => YoutubeEndpoints.channelIdPattern.hasMatch(id)
      ? '${YoutubeEndpoints.origin}/channel/$id/live'
      : '${YoutubeEndpoints.origin}/$id/live';

  /// The broadcast a room id names: [id] itself when it is already a video id,
  /// else the current live video of the channel it names (resolved through
  /// `navigation/resolve_url`).
  Future<String> resolveVideoId(String id) async {
    final trimmed = id.trim();
    if (YoutubeEndpoints.videoIdPattern.hasMatch(trimmed)) return trimmed;
    final response = await post('navigation/resolve_url', YoutubeEndpoints.resolveUrlBody(_channelLiveUrl(trimmed)));
    final resolved = YoutubeRoomParser.resolveUrl(response.text);
    final videoId = resolved.videoId;
    if (videoId != null && videoId.isNotEmpty) return videoId;
    throw YouTubeFailure(YoutubeFailureKind.notFound, 'channel $trimmed names no live broadcast');
  }

  /// The video id or channel id a `navigation/resolve_url` answer names for
  /// [url] (the link resolver's and [resolveVideoId]'s shared lookup).
  Future<YoutubeResolved> resolveUrl(String url) async {
    final response = await post('navigation/resolve_url', YoutubeEndpoints.resolveUrlBody(url));
    return YoutubeRoomParser.resolveUrl(response.text);
  }

  /// A follow refresh without any page: a video id is its `player` answer
  /// (live, with the viewer count of `updated_metadata`); a channel id or
  /// handle is `navigation/resolve_url` of its `/live` path and the
  /// broadcast that names, a broadcast no longer live asking its channel the
  /// same way. A channel naming no broadcast refreshes to the bare offline
  /// room — the follow keeps what it stored. Any step of the small path
  /// failing falls back to the paired-page entry ([detail]).
  Future<LiveRoom> refreshRoom(String roomId) async {
    final trimmed = roomId.trim();
    if (trimmed.isEmpty) throw const YouTubeFailure(YoutubeFailureKind.notFound, 'empty room id');
    try {
      final room = await _pageless(trimmed);
      if (room != null) return room;
    } on Object {
      // The small path failed: the full entry answers instead.
    }
    return await detail(trimmed);
  }

  /// [roomId] through the pageless path, null when it cannot answer (the
  /// caller falls back to the full entry): a video id is [_pagelessVideo],
  /// one no longer live its channel's ([_pagelessChannel]); a channel id or
  /// handle [_pagelessChannel] at once.
  Future<LiveRoom?> _pageless(String roomId) async {
    if (YoutubeEndpoints.videoIdPattern.hasMatch(roomId)) {
      final room = await _pagelessVideo(roomId);
      if (room == null || room.broadcast.liveStatus == LiveStatus.live) return room;
      final owner = room.anchor?.anchorId ?? '';
      if (owner.isEmpty) return room;
      return await _pagelessChannel(owner, known: room);
    }
    return await _pagelessChannel(roomId);
  }

  /// The room of [videoId] from its `player` answer alone; live, with the
  /// viewer count of `updated_metadata` (a count that fails leaves the
  /// `player` room). Null when [channelId] is given and the video proves to
  /// be another channel's or no longer live.
  Future<LiveRoom?> _pagelessVideo(String videoId, {String? channelId}) async {
    final player = await post(
      'player',
      YoutubeEndpoints.playerBody(videoId),
      referer: YoutubeEndpoints.watchUrl(videoId),
      key: true,
    );
    final room = YoutubeRoomParser.room(player.text, '{}', requestedId: videoId).room;
    final owner = room.anchor?.anchorId ?? '';
    if (channelId != null && owner.isNotEmpty && owner != channelId) return null;
    if (room.broadcast.liveStatus != LiveStatus.live) return channelId == null ? room : null;
    return await _withViewers(room, videoId);
  }

  /// [room] with the concurrent viewer count of its broadcast [videoId]
  /// (`updated_metadata`); a count that fails, or that the answer names not,
  /// leaves the room as it was.
  Future<LiveRoom> _withViewers(LiveRoom room, String videoId) async {
    final int? viewers;
    try {
      final response = await post(
        'updated_metadata',
        YoutubeEndpoints.metadataBody(videoId),
        referer: YoutubeEndpoints.watchUrl(videoId),
      );
      viewers = YoutubeRoomParser.viewers(response.text);
    } on Object {
      return room;
    }
    if (viewers == null) return room;
    return room.rebuild((b) => b..audience.onlineViewers = viewers);
  }

  /// The room of [channelId] (`UC…` or a handle) without any page:
  /// `navigation/resolve_url` of its `/live` path names its broadcast (on
  /// air, or the next one) or the channel; the broadcast's `player` answer
  /// gives the state, live the viewer count too. A broadcast of another
  /// channel is not this channel's; [known] (a video of this channel the
  /// caller found ended) is the room when the path names no broadcast; a
  /// channel naming neither is the bare offline room — the follow keeps what
  /// it stored.
  Future<LiveRoom> _pagelessChannel(String channelId, {LiveRoom? known}) async {
    final resolved = await resolveUrl(_channelLiveUrl(channelId));
    final videoId = resolved.videoId;
    if (videoId != null && videoId.isNotEmpty) {
      final room = await _pagelessVideo(videoId, channelId: channelId);
      if (room != null) return room;
    }
    final browseId = resolved.browseId;
    if (browseId != null &&
        browseId.isNotEmpty &&
        YoutubeEndpoints.channelIdPattern.hasMatch(channelId) &&
        browseId != channelId) {
      throw YouTubeFailure(YoutubeFailureKind.apiChanged, 'resolve_url: asked for $channelId, answered $browseId');
    }
    if (known != null) return known;
    final id = browseId == null || browseId.isEmpty ? channelId : browseId;
    return LiveRoom.normalized(
      platform: youtubeSiteId,
      roomId: id,
      broadcast: RoomBroadcast.of(liveStatus: LiveStatus.offline),
      links: RoomLinks.of(webUrl: _channelLiveUrl(id)),
    );
  }

  /// GETs a media manifest (an HLS master) with the media headers of [videoId].
  Future<YouTubeResponse> fetchMaster(String url, String videoId) =>
      http.get(Uri.parse(url), headers: YoutubeEndpoints.mediaHeaders(videoId));

  // Catalog and search --------------------------------------------------------

  /// The Live hub (`youtube.com/live`): one page of live rooms (ended and
  /// upcoming rows are left out; a page without any video row is api-changed).
  /// The broadcast each live card shows is remembered for its channel.
  Future<({List<LiveRoom> rooms, String? continuation})> hub() async {
    final response = await post('browse', YoutubeEndpoints.browseBody());
    final node = _decoded(response.text, 'browse');
    final listing = YoutubeRoomParser.listing(node, search: false);
    _rememberListing(listing.rooms);
    return (rooms: listing.rooms, continuation: listing.continuation);
  }

  /// One search page: [query] fresh (the literal Live filter), or the
  /// [continuation] token a later page was handed. A page whose live rows were
  /// all malformed is api-changed, and a page without a live row names no
  /// continuation (the list ends). The broadcast each live card shows is
  /// remembered for its channel.
  Future<({List<LiveRoom> rooms, String? continuation})> searchPage(String query, {String? continuation}) async {
    final body = continuation == null
        ? YoutubeEndpoints.searchPage1Body(query)
        : YoutubeEndpoints.searchContinuationBody(continuation);
    final response = await post('search', body, referer: '${YoutubeEndpoints.origin}/results?search_query=');
    final node = _decoded(response.text, 'search');
    final listing = YoutubeRoomParser.listing(node, search: true);
    _rememberListing(listing.rooms);
    return (rooms: listing.rooms, continuation: listing.continuation);
  }

  /// [text] decoded as JSON for [what]; a malformed body is an api-changed
  /// failure.
  static Object? _decoded(String text, String what) {
    try {
      return jsonDecode(text);
    } on FormatException {
      throw YouTubeFailure(YoutubeFailureKind.apiChanged, '$what: not JSON');
    }
  }

  // Capability wiring ---------------------------------------------------------

  YoutubeRoomProvider? _room;
  YoutubeDiscoveryProvider? _discovery;
  YoutubeSearchProvider? _search;
  YoutubePlaybackProvider? _playback;
  YoutubePlayLeaseLookup? _lease;
  YoutubeDanmakuProvider? _danmaku;
  YoutubeLinkResolver? _link;
  YoutubeRoomRefresh? _refresh;
  YoutubeStatusCheck? _status;

  /// The capability of type [T], or null when youtube does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site. There is no
  /// `LiveAreaProvider`: YouTube has no areas, so asking for one returns null.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= YoutubeRoomProvider(site: this);
    final discovery = _discovery ??= YoutubeDiscoveryProvider(site: this);
    final search = _search ??= YoutubeSearchProvider(site: this);
    final playback = _playback ??= YoutubePlaybackProvider(site: this);
    final lease = _lease ??= YoutubePlayLeaseLookup(now: now);
    final danmaku = _danmaku ??= YoutubeDanmakuProvider(site: this, allChat: allChat);
    final link = _link ??= YoutubeLinkResolver(site: this);
    final refresh = _refresh ??= YoutubeRoomRefresh(site: this);
    final status = _status ??= YoutubeStatusCheck(refresh: refresh);
    return switch (T) {
      const (LiveRoomProvider) => room as T,
      const (LiveDiscoveryProvider) => discovery as T,
      const (LiveSearchProvider) => search as T,
      const (LivePlaybackProvider) => playback as T,
      const (LivePlayLeaseLookup) => lease as T,
      const (LiveDanmakuProvider) => danmaku as T,
      const (LiveLinkResolver) => link as T,
      const (LiveRoomRefresh) => refresh as T,
      const (LiveStatusCheck) => status as T,
      _ => null,
    };
  }
}
