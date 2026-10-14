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
import 'package:live_sites/src/platforms/kick/api/kick_endpoints.dart';
import 'package:live_sites/src/platforms/kick/api/kick_http.dart';
import 'package:live_sites/src/platforms/kick/capabilities/kick_area_provider.dart';
import 'package:live_sites/src/platforms/kick/capabilities/kick_discovery_provider.dart';
import 'package:live_sites/src/platforms/kick/capabilities/kick_link_resolver.dart';
import 'package:live_sites/src/platforms/kick/capabilities/kick_playback_provider.dart';
import 'package:live_sites/src/platforms/kick/capabilities/kick_room_provider.dart';
import 'package:live_sites/src/platforms/kick/capabilities/kick_search_provider.dart';
import 'package:live_sites/src/platforms/kick/danmaku/kick_danmaku_session.dart';
import 'package:live_sites/src/platforms/kick/kick_manifest.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_failure.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What a danmaku session needs for one channel: the chatroom id (never the
/// channel id — `xqcisoffline` is channel 101691 but chatroom 101689), the
/// channel id (its `channel.<id>` carries the broadcast's own events and
/// `channel_<id>` the Kicks sent) and the slug for the media headers.
final class KickDanmakuArgs {
  /// Wraps the two numeric ids and the slug.
  const KickDanmakuArgs({required this.chatroomId, required this.channelId, required this.slug});

  /// `chatroom.id`: the Pusher channel `chatrooms.<id>.v2` carries the chat.
  final int chatroomId;

  /// The channel's numeric id.
  final int channelId;

  /// The channel slug, the room id.
  final String slug;

  @override
  String toString() => 'KickDanmakuArgs($slug, chatroom $chatroomId, channel $channelId)';
}

/// The Kick adapter: manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2); requests in `api/`, parsing in `parsers/`,
/// features in `capabilities/`.
///
/// Anonymous and read-only: no auth, no csrf token, no client id — Kick's
/// web API answers the plain browser headers. Room ids are channel slugs in
/// lower case (Kick finds a channel in any case, and this codebase keeps no
/// case-normalizing table, so the adapter lower-cases the slug itself).
/// Chat runs over Kick's Pusher app (hand-rolled JSON frames), playback is
/// the channel answer's signed IVS master playlist.
///
/// Not yet wired into `built_in_sites`: the orchestrator defers the
/// registration of this platform, so the registry does not build it.
final class KickSite implements LiveSite {
  /// Creates the adapter over [http]; [now] is injectable for tests.
  KickSite({required this.http, DateTime Function()? now}) : now = now ?? DateTime.now;

  /// Transport.
  final KickHttp http;

  /// Injectable clock (master-playlist cache ages).
  final DateTime Function() now;

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => kickManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O already).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  /// GETs [url] with [headers] (the capabilities' transport).
  Future<({String text, int status})> httpGet(Uri url, {Map<String, String> headers = const {}}) =>
      http.get(url, headers: headers);

  /// The API request headers (identical for every endpoint: Kick checks no
  /// login, referer or origin beyond these).
  Map<String, String> apiHeaders() => KickEndpoints.headers;

  /// The channel [roomId] (a slug in any case; the room id is the lower-case
  /// slug). Not a slug is not-found without a request.
  Future<KickChannel> channel(String roomId) async {
    final slug = KickEndpoints.normalizeSlug(roomId);
    if (slug == null) {
      throw KickFailure(KickFailureKind.notFound, 'room id "${roomId.trim()}" is not a Kick channel');
    }
    final response = await http.get(KickEndpoints.channel(slug), headers: apiHeaders());
    return KickRoomParser.channel(response.text, requestedSlug: slug, status: response.status);
  }

  // Capability wiring ---------------------------------------------------------

  KickRoomProvider? _room;
  KickAreaProvider? _area;
  KickDiscoveryProvider? _discovery;
  KickSearchProvider? _search;
  KickPlaybackProvider? _playback;
  KickDanmakuProvider? _danmaku;
  KickLinkResolver? _link;

  /// The capability of type [T], or null when kick does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= KickRoomProvider(site: this);
    final area = _area ??= KickAreaProvider(site: this);
    final discovery = _discovery ??= KickDiscoveryProvider(site: this);
    final search = _search ??= KickSearchProvider(site: this);
    final playback = _playback ??= KickPlaybackProvider(site: this);
    final danmaku = _danmaku ??= KickDanmakuProvider(site: this);
    final link = _link ??= KickLinkResolver(site: this);
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
