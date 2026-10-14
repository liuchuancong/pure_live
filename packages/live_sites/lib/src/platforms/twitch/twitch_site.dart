import 'dart:async';
import 'dart:math';

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
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/twitch/api/twitch_endpoints.dart';
import 'package:live_sites/src/platforms/twitch/api/twitch_http.dart';
import 'package:live_sites/src/platforms/twitch/capabilities/twitch_area_provider.dart';
import 'package:live_sites/src/platforms/twitch/capabilities/twitch_discovery_provider.dart';
import 'package:live_sites/src/platforms/twitch/capabilities/twitch_link_resolver.dart';
import 'package:live_sites/src/platforms/twitch/capabilities/twitch_playback_provider.dart';
import 'package:live_sites/src/platforms/twitch/capabilities/twitch_room_provider.dart';
import 'package:live_sites/src/platforms/twitch/capabilities/twitch_search_provider.dart';
import 'package:live_sites/src/platforms/twitch/danmaku/twitch_danmaku_session.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_failure.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_json.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_play_parser.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_room_parser.dart';
import 'package:live_sites/src/platforms/twitch/twitch_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Continuation cursors kept (the oldest goes first).
const int _cursorLimit = 256;

/// List snapshots kept (the oldest goes first).
const int _snapshotLimit = 16;

/// How long a list snapshot serves the pages after the first; the first page
/// always fetches a new one.
const Duration _snapshotLifetime = Duration(seconds: 30);

final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F]');

/// One list's streams as fetched so far, cut into pages locally: the rooms in
/// the server's order (each once), the cursor of the next chunk, when the
/// first chunk arrived, and where each page served so far ended.
final class _Snapshot {
  _Snapshot(this.fetchedAt);

  final DateTime fetchedAt;
  final List<LiveRoom> rooms = [];
  final Set<String> _ids = {};
  final Map<int, int> starts = {};
  String? cursor;

  /// Adds a chunk; a chunk that brings no new room ends the list (a cursor
  /// that goes nowhere must not be followed forever).
  void add(({List<LiveRoom> rooms, String? cursor}) chunk) {
    var added = false;
    for (final room in chunk.rooms) {
      if (_ids.add(room.identityKey)) {
        rooms.add(room);
        added = true;
      }
    }
    cursor = added ? chunk.cursor : null;
  }
}

/// The Twitch adapter: manifest + capability discovery + lifecycle
/// (ARCHITECTURE.md §7.2).
///
/// **Twitch.** Every request is anonymous except the playback access token,
/// which carries the stored session when there is one and is asked again
/// without it when Twitch refuses that session (HTTP 401 or an integrity
/// challenge); the refused cookie is not sent again until it changes. Names
/// come back in the web client's own language (`accept-language: en-US,en`).
///
/// **Lists.** An area's streams are fetched 100 at a time, the site's busiest
/// streams 30 at a time (the most Twitch gives); pages of any size are cut
/// from that snapshot, each where the one before ended, and a page starting
/// past its end follows the cursor for the next chunk. The first page always
/// fetches anew; later pages use the snapshot while it is under 30 s old. Both
/// lists keep only the broadcast languages of [languages]. A chunk answered
/// with an integrity challenge ends the list quietly — anonymous clients get
/// the first chunk only. Search follows the channel cursor.
///
/// Failures are [TwitchFailure]s; nothing is disguised as an offline room.
final class TwitchSite implements LiveSite {
  /// Creates the adapter over [http]. The settings are read per request, so a
  /// change needs no new adapter: [loginCookie] is the user's stored cookie
  /// (null: a guest); [languages] reads the broadcast-language filter (Twitch
  /// codes such as `ZH`, `KO`; none keeps every language); [preferH264] reads
  /// "优先 H.264" (on by default): usher is asked for H.264 only, else also for
  /// HEVC and AV1 as far as [codecs] says the engine decodes them (`avc`,
  /// `hevc`, `av1`; null: all). [now] and [random] (the `Device-Id`, the usher
  /// nonce) are injectable for tests.
  factory TwitchSite({
    required TwitchHttp http,
    String Function()? loginCookie,
    List<String> Function()? languages,
    bool Function()? preferH264,
    Set<String>? Function()? codecs,
    DateTime Function()? now,
    Random? random,
  }) {
    final source = random ?? Random.secure();
    return TwitchSite._(
      http,
      loginCookie ?? _guest,
      languages ?? _everyLanguage,
      preferH264 ?? _on,
      codecs ?? _unknownCodecs,
      now ?? DateTime.now,
      source,
    );
  }

  TwitchSite._(this.http, this.loginCookie, this.languages, this.preferH264, this.codecs, this.now, this._random);

  static String _guest() => '';
  static List<String> _everyLanguage() => const [];
  static bool _on() => true;
  static Set<String>? _unknownCodecs() => null;

  /// Transport (usher and GraphQL alike).
  final TwitchHttp http;

  /// The user's stored cookie, read per request so a changed login applies at
  /// once.
  final String Function() loginCookie;

  /// The broadcast languages of the "Twitch 语言筛选" setting.
  final List<String> Function() languages;

  /// Whether usher is asked for H.264 only ("优先 H.264", on by default).
  final bool Function() preferH264;

  /// The video codecs the player's engine decodes; null when not known.
  final Set<String>? Function() codecs;

  /// Injectable clock (covers' `?&t=`, snapshot ages).
  final DateTime Function() now;

  final Random _random;

  /// The `Device-Id` of every GraphQL and usher request: one per adapter.
  late final String deviceId = TwitchEndpoints.deviceId(_random);

  /// The cursor of each search page after the first, by `search|keyword|page`.
  final Map<String, String> _cursors = {};

  /// The area and recommendation snapshots, by list and languages.
  final Map<String, _Snapshot> _snapshots = {};

  /// The stored cookie Twitch refused for the access token; anonymous tokens
  /// are used until it changes.
  String? _rejectedSession;

  /// The game slug of each area, by its game id, as the last [categories] walk
  /// named them.
  final Map<String, String> _slugs = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => twitchManifest;

  /// The current runtime status (stateless adapter: ready once built).
  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  /// Initializes (nothing to do: construction performs no I/O).
  @override
  Future<void> initialize(LiveSiteContext context) async {}

  /// Releases the pooled transports of the wrapped transport.
  @override
  Future<void> dispose() async => http.close();

  // Headers -------------------------------------------------------------------

  /// The GraphQL headers, with the adapter's [deviceId] and asking for
  /// [language]; [cookie] adds the stored `Cookie` and, when it holds an
  /// `auth-token`, `Authorization: OAuth <token>`.
  Map<String, String> gqlHeaders({String cookie = '', String language = TwitchEndpoints.acceptLanguage}) {
    final token = twitchAuthToken(cookie);
    return {
      ..._identity(language),
      'content-type': 'text/plain;charset=UTF-8',
      if (cookie.isNotEmpty) 'cookie': cookie,
      if (token != null) 'authorization': 'OAuth $token',
    };
  }

  /// The usher headers: the GraphQL identity, without the session.
  Map<String, String> usherHeaders() => _identity(TwitchEndpoints.acceptLanguage);

  Map<String, String> _identity(String language) => {
    'user-agent': TwitchEndpoints.userAgent,
    'accept-language': language,
    'accept': TwitchEndpoints.accept,
    'client-id': TwitchEndpoints.clientId,
    'origin': TwitchEndpoints.origin,
    'referer': '${TwitchEndpoints.origin}/',
    'device-id': deviceId,
  };

  /// The chat login of a stored cookie (`login` with `auth-token`), or null.
  ({String login, String token})? chat() => twitchChatLogin(login());

  // Session -------------------------------------------------------------------

  /// The user's cookie ('' when signed out), control characters and a pasted
  /// `Cookie:` prefix stripped.
  String login() {
    final raw = loginCookie().replaceAll(_controlCharacters, '').trim();
    return raw.toLowerCase().startsWith('cookie:') ? raw.substring(7).trim() : raw;
  }

  // Requests ------------------------------------------------------------------

  /// One GraphQL request of [operation] (an operation or a batch), decoded.
  /// The stored session goes only where [cookie] asks for it.
  Future<Object> gql(
    Object operation, {
    String what = 'gql',
    String cookie = '',
    String language = TwitchEndpoints.acceptLanguage,
  }) async {
    final response = await http.gql(
      operation,
      headers: gqlHeaders(cookie: cookie, language: language),
    );
    return TwitchJson.decode(response.text, status: response.status, what: what);
  }

  /// usher's master playlist of [login] with a fresh access token: the
  /// variant groups, best first.
  ///
  /// The token is asked for with the stored session when there is one (a
  /// subscriber's or Turbo token); when Twitch refuses that session the token
  /// is asked for anonymously and that cookie is not sent again until it
  /// changes. When the detail marked the stream restricted and Twitch refuses
  /// this viewer, the refusal is stream-unavailable naming the restriction.
  Future<List<TwitchVariantGroup>> playlist(String login, {LiveRestriction? restriction}) async {
    final channel = login.trim().toLowerCase();
    if (!TwitchEndpoints.loginPattern.hasMatch(channel)) {
      throw TwitchFailure(TwitchFailureKind.notFound, 'not a channel login: $login');
    }
    try {
      final token = await accessToken(channel);
      final url = TwitchEndpoints.usherUrl(
        channel,
        value: token.value,
        signature: token.signature,
        random: _random,
        preferH264: preferH264(),
        codecs: codecs(),
      );
      final answer = await http.get(url, headers: usherHeaders());
      TwitchPlayParser.usherStatus(answer.status, answer.text);
      return TwitchPlayParser.groups(answer.text, master: url);
    } on TwitchFailure catch (failure) {
      if (failure.kind != TwitchFailureKind.needsLogin || restriction == null) rethrow;
      throw TwitchFailure(
        TwitchFailureKind.streamUnavailable,
        'restricted stream (${restriction.name}): ${failure.message}',
        cause: failure,
      );
    }
  }

  /// `PlaybackAccessToken` of [login], with the stored session when there is
  /// one and anonymously after that session was refused.
  Future<TwitchAccessToken> accessToken(String channel) async {
    final operation = TwitchEndpoints.accessTokenOperation(channel);
    final session = login();
    if (session.isNotEmpty && session != _rejectedSession) {
      Object? answer;
      try {
        answer = await gql(operation, what: 'PlaybackAccessToken', cookie: session);
      } on TwitchFailure catch (failure) {
        if (failure.kind != TwitchFailureKind.needsLogin && failure.kind != TwitchFailureKind.riskControl) rethrow;
        _rejectedSession = session;
      }
      if (answer != null) return TwitchRoomParser.accessToken(answer, login: channel);
    }
    return TwitchRoomParser.accessToken(await gql(operation, what: 'PlaybackAccessToken'), login: channel);
  }

  // Rooms ---------------------------------------------------------------------

  /// The channel [roomId] (a login in any case; the request uses it lower
  /// case, the room keeps the id as asked). Not a login is not-found without
  /// a request.
  Future<LiveRoom> detail(String roomId) async {
    final id = roomId.trim();
    final login = TwitchRoomParser.loginOf(id);
    if (login == null) throw TwitchFailure(TwitchFailureKind.notFound, 'not a channel login: $id');
    return TwitchRoomParser.roomDetail(
      await gql(TwitchEndpoints.userOperation(login), what: 'user'),
      requestedId: id,
      now: now(),
    );
  }

  // Catalog -------------------------------------------------------------------

  /// The game slug [areaId] names: the one the last [categories] walk read,
  /// else the id itself (Twitch's directory slugs are the readable game names a
  /// caller may well have).
  String slugFor(String areaId) => _slugs[areaId.trim()] ?? areaId.trim();

  /// The category tags with their directories: 30 directories a page, and a
  /// tag's next page while its last one was full and had a cursor. The pages
  /// of a round go out together in batches of at most 35 operations. A failed
  /// first round fails the catalog; a failed later round ends those tags with
  /// the pages they have (an anonymous client is asked for an integrity token
  /// there).
  Future<List<LiveArea>> categories() async {
    final tags = TwitchRoomParser.tags(await gql(TwitchEndpoints.tagsOperation(), what: 'SearchCategoryTags'));
    final areas = {for (final tag in tags) tag.id: <LiveArea>[]};
    final seen = <String>{};
    var pages = [for (final tag in tags) (tag: tag, cursor: null as String?)];
    for (var round = 0; pages.isNotEmpty && round < TwitchEndpoints.tagPageLimit; round++) {
      final answers = await _directoryRound(pages, lenient: round > 0);
      pages = [];
      for (final answer in answers) {
        areas[answer.tag.id]!.addAll(answer.areas);
        final cursor = answer.cursor;
        if (answer.areas.length >= TwitchEndpoints.tagDirectoryLimit &&
            cursor != null &&
            seen.add('${answer.tag.id}|$cursor')) {
          pages.add((tag: answer.tag, cursor: cursor));
        }
      }
    }
    _slugs
      ..clear()
      ..addEntries([
        for (final entry in areas.entries)
          for (final area in entry.value)
            if (area.shortName case final slug? when slug.isNotEmpty) MapEntry(area.areaId, slug),
      ]);
    return [for (final tag in tags) ...areas[tag.id]!];
  }

  /// One page of directories for each of [pages], in batches of at most 35
  /// operations sent together. With [lenient] a failed batch gives nothing.
  Future<List<({TwitchTag tag, List<LiveArea> areas, String? cursor})>> _directoryRound(
    List<({TwitchTag tag, String? cursor})> pages, {
    required bool lenient,
  }) async {
    final chunks = [
      for (var start = 0; start < pages.length; start += TwitchEndpoints.batchLimit)
        pages.sublist(start, min(start + TwitchEndpoints.batchLimit, pages.length)),
    ];
    Future<List<({TwitchTag tag, List<LiveArea> areas, String? cursor})>> ask(
      List<({TwitchTag tag, String? cursor})> chunk,
    ) async {
      const what = 'BrowsePage_AllDirectories';
      try {
        final answer = await gql([
          for (final page in chunk) TwitchEndpoints.directoriesOperation(page.tag.id, cursor: page.cursor),
        ], what: what);
        final envelopes = TwitchJson.batch(answer, expected: chunk.length, what: what);
        return [
          for (final (index, envelope) in envelopes.indexed)
            (
              tag: chunk[index].tag,
              areas: TwitchRoomParser.directories(envelope, chunk[index].tag).areas,
              cursor: TwitchRoomParser.directories(envelope, chunk[index].tag).cursor,
            ),
        ];
      } on TwitchFailure {
        if (lenient) return const [];
        rethrow;
      }
    }

    return [
      for (final answers in await Future.wait([for (final chunk in chunks) ask(chunk)])) ...answers,
    ];
  }

  // Lists ---------------------------------------------------------------------

  /// The busiest live streams of the whole site (3.x's recommendations), in
  /// the chosen languages, 30 at a time and cut into pages locally.
  Future<({List<LiveRoom> rooms, bool hasMore})> recommend(int page, int pageSize) async {
    final chosen = chosenLanguages();
    final rooms = await _page('recommend|${chosen.join(',')}', page, pageSize, (cursor) async {
      final answer = await gql(
        TwitchEndpoints.streamsOperation(limit: TwitchEndpoints.streamsLimit, cursor: cursor, languages: chosen),
        what: 'streams',
      );
      return TwitchRoomParser.streams(answer, now: now());
    });
    return (rooms: rooms, hasMore: rooms.isNotEmpty);
  }

  /// The streams of the directory [slug] (its short name), fetched 100 at a
  /// time and cut into pages locally, in the chosen languages. An unknown
  /// directory is not-found; an area without a slug has no streams, without a
  /// request.
  Future<({List<LiveRoom> rooms, bool hasMore})> areaRooms(String slug, int page, int pageSize) async {
    final channel = slug.trim();
    if (channel.isEmpty) return (rooms: const <LiveRoom>[], hasMore: false);
    final chosen = chosenLanguages();
    final rooms = await _page('area|$channel|${chosen.join(',')}', page, pageSize, (cursor) async {
      final answer = await gql([
        TwitchEndpoints.gameOperation(
          channel,
          limit: TwitchEndpoints.directoryFetchLimit,
          cursor: cursor,
          languages: chosen,
        ),
      ], what: 'DirectoryPage_Game');
      return TwitchRoomParser.gameStreams(answer, now: now(), slug: channel);
    });
    return (rooms: rooms, hasMore: rooms.isNotEmpty);
  }

  /// The chosen languages of the setting, as Twitch spells them.
  List<String> chosenLanguages() => TwitchEndpoints.normalizeLanguages(languages());

  /// Page [page] of the list [key]: up to [pageSize] (1–100) rooms cut from
  /// its snapshot, starting where the page before ended.
  /// - The first page fetches a new snapshot; a later one does when the
  ///   snapshot is missing or 30 s old.
  /// - Only a page that would start past the snapshot's end fetches the next
  ///   chunk from its cursor, so a page may hold fewer rooms than asked; an
  ///   empty page is the end. (Filling every page would cost the busiest list
  ///   a second request each time: Twitch often gives 29 of the 30 asked for.)
  /// - A chunk answered with an integrity challenge ends the list quietly;
  ///   other failures fail the page and keep the cursor.
  Future<List<LiveRoom>> _page(
    String key,
    int page,
    int pageSize,
    Future<({List<LiveRoom> rooms, String? cursor})> Function(String? cursor) fetch,
  ) async {
    final number = page < 1 ? 1 : page;
    final size = pageSize.clamp(1, 100);
    var snapshot = _snapshots[key];
    final at = now();
    if (number == 1 || snapshot == null || at.difference(snapshot.fetchedAt) >= _snapshotLifetime) {
      final fresh = _Snapshot(at)..add(await fetch(null));
      _snapshots
        ..remove(key)
        ..[key] = fresh;
      if (_snapshots.length > _snapshotLimit) _snapshots.remove(_snapshots.keys.first);
      snapshot = fresh;
    }
    final start = number == 1 ? 0 : snapshot.starts[number] ?? (number - 1) * size;
    while (start >= snapshot.rooms.length && snapshot.cursor != null) {
      try {
        snapshot.add(await fetch(snapshot.cursor));
      } on TwitchFailure catch (failure) {
        if (failure.kind != TwitchFailureKind.riskControl) rethrow;
        snapshot.cursor = null;
      }
    }
    final rooms = snapshot.rooms;
    if (start >= rooms.length) return const [];
    final end = min(start + size, rooms.length);
    snapshot.starts[number + 1] = end;
    return List.unmodifiable(rooms.sublist(start, end));
  }

  // Search --------------------------------------------------------------------

  /// Channels matching [keyword], live or not, page by page along the channel
  /// cursor in `options.targets` (a top-level cursor is ignored by the
  /// server). A blank keyword gives nothing without a request.
  Future<({List<LiveRoom> rooms, String? cursor})> search(String keyword, int page) async {
    final text = keyword.trim();
    if (text.isEmpty) return (rooms: const <LiveRoom>[], cursor: null);
    final number = page < 1 ? 1 : page;
    final key = 'search|$text';
    final cursor = number == 1 ? null : _cursors['$key|$number'];
    if (number > 1 && cursor == null) return (rooms: const <LiveRoom>[], cursor: null);
    final Object answer;
    try {
      answer = await gql(
        TwitchEndpoints.searchOperation(text, cursor: cursor),
        what: 'SearchResultsPage_SearchResults',
      );
    } on TwitchFailure catch (failure) {
      if (failure.kind != TwitchFailureKind.riskControl || cursor == null) rethrow;
      return (rooms: const <LiveRoom>[], cursor: null);
    }
    final result = TwitchRoomParser.searchPage(answer, now: now());
    _remember('$key|${number + 1}', result.cursor);
    return result;
  }

  /// Remembers the cursor of continuation page [key], or forgets it at the end
  /// of the list.
  void _remember(String key, String? cursor) {
    _cursors.remove(key);
    if (cursor == null) return;
    _cursors[key] = cursor;
    if (_cursors.length > _cursorLimit) _cursors.remove(_cursors.keys.first);
  }

  // Links ---------------------------------------------------------------------

  /// The channel login a link names: a first path segment of `twitch.tv`
  /// (`www`, `m`, `go`), a pop-out chat (`/popout/<login>/chat`) or the
  /// embedded player (`player.twitch.tv/?channel=<login>`). The login keeps
  /// the case it was written in; Twitch's own pages are not channels. Null
  /// when the link names none.
  static String? loginFromUrl(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'player.twitch.tv') return _channel(uri.queryParameters['channel']?.trim() ?? '');
    if (!TwitchEndpoints.channelHosts.contains(host)) return null;
    final segments = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    if (segments.isEmpty) return null;
    final popout = segments.first.toLowerCase() == 'popout' && segments.length >= 2;
    return _channel((popout ? segments[1] : segments.first).trim());
  }

  static String? _channel(String segment) =>
      TwitchEndpoints.linkLogin.hasMatch(segment) && !TwitchEndpoints.sitePages.contains(segment.toLowerCase())
      ? segment
      : null;

  // Capability wiring ---------------------------------------------------------

  TwitchRoomProvider? _room;
  TwitchAreaProvider? _area;
  TwitchDiscoveryProvider? _discovery;
  TwitchSearchProvider? _search;
  TwitchPlaybackProvider? _playback;
  TwitchDanmakuProvider? _danmaku;
  TwitchLinkResolver? _link;

  /// The capability of type [T], or null when twitch does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= TwitchRoomProvider(site: this);
    final area = _area ??= TwitchAreaProvider(site: this);
    final discovery = _discovery ??= TwitchDiscoveryProvider(site: this);
    final search = _search ??= TwitchSearchProvider(site: this);
    final playback = _playback ??= TwitchPlaybackProvider(site: this);
    final danmaku = _danmaku ??= TwitchDanmakuProvider(site: this);
    final link = _link ??= TwitchLinkResolver(site: this);
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
