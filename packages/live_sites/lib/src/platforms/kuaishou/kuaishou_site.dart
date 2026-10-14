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
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/kuaishou/api/kuaishou_endpoints.dart';
import 'package:live_sites/src/platforms/kuaishou/api/kuaishou_http.dart';
import 'package:live_sites/src/platforms/kuaishou/capabilities/kuaishou_area_provider.dart';
import 'package:live_sites/src/platforms/kuaishou/capabilities/kuaishou_discovery_provider.dart';
import 'package:live_sites/src/platforms/kuaishou/capabilities/kuaishou_link_resolver.dart';
import 'package:live_sites/src/platforms/kuaishou/capabilities/kuaishou_playback_provider.dart';
import 'package:live_sites/src/platforms/kuaishou/capabilities/kuaishou_room_provider.dart';
import 'package:live_sites/src/platforms/kuaishou/capabilities/kuaishou_search_provider.dart';
import 'package:live_sites/src/platforms/kuaishou/danmaku/kuaishou_danmaku_session.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_manifest.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_failure.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How long an anonymous session is sent before the next room entry starts a
/// new one (30 minutes).
const Duration _sessionLifetime = Duration(minutes: 30);

/// The broadcast behind a room, apart from the room's identity: this
/// broadcast's `liveStreamId`, the raw `playUrls` and when the page carrying
/// them arrived (the origin of the signed URLs' leases). It rides in the
/// room's transient stream handle.
final class KuaishouRoomData {
  /// Wraps the stream handle.
  const KuaishouRoomData({required this.issuedAt, this.liveStreamId, this.playUrls});

  /// When the detail carrying [playUrls] arrived.
  final DateTime issuedAt;

  /// Id of the current broadcast; null when the room is offline.
  final String? liveStreamId;

  /// The raw `playUrls`: the room page's `{h264, hevc}` object or a card's
  /// descriptor list; null when it was not asked for.
  final Object? playUrls;

  @override
  String toString() => 'KuaishouRoomData(${liveStreamId ?? '-'})';
}

/// What the comment feed needs to follow one broadcast: the broadcast's
/// `liveStreamId` and the cookie in effect when the room was read (the user's,
/// else the anonymous session's, else empty).
final class KuaishouDanmakuArgs {
  /// Wraps the feed arguments.
  const KuaishouDanmakuArgs({required this.liveStreamId, this.cookie = ''});

  /// Id of the current broadcast (a new one every broadcast).
  final String liveStreamId;

  /// The `cookie` header for the feed requests; empty for none.
  final String cookie;

  @override
  String toString() => 'KuaishouDanmakuArgs($liveStreamId, ${cookie.isEmpty ? 'guest' : '<redacted>'})';
}

/// The Kuaishou adapter (parsing in `parsers/`): manifest + capability
/// discovery + lifecycle (ARCHITECTURE.md §7.2).
///
/// Every request names one desktop browser ([_browser]: a UA and matching
/// client hints), picked anew with each anonymous session. Lists and search go
/// without a cookie. Room pages carry the user's cookie when one is configured,
/// else an anonymous session: a bare visit of the room page whose `Set-Cookie`
/// (`did`, `clientid`, `client_key`, `kpn`, `kuaishou.live.bfb1s`) is kept for
/// 30 minutes, its device id reported once (best effort), shared by concurrent
/// callers. Media requests carry only the user's cookie. Failures are
/// [KuaishouFailure]s; nothing is disguised as an offline room.
final class KuaishouSite implements LiveSite {
  /// Creates the adapter over [http]. [loginCookie] supplies the user's cookie
  /// (null: a guest), read per request; [preferH264] reads "优先 H.264" (on by
  /// default) at each call; [now] and [random] (the browser identity, the
  /// device report's counter) are injectable for tests.
  factory KuaishouSite({
    required KuaishouHttp http,
    String Function()? loginCookie,
    bool Function()? preferH264,
    DateTime Function()? now,
    Random? random,
  }) {
    final source = random ?? Random.secure();
    return KuaishouSite._(http, loginCookie ?? _guest, preferH264 ?? _on, now ?? DateTime.now, source);
  }

  KuaishouSite._(this.http, this.loginCookie, this.preferH264, this.now, this._random);

  static String _guest() => '';
  static bool _on() => true;

  /// Transport (the capabilities' and the comment feed's).
  final KuaishouHttp http;

  /// The user's login cookie, read per request so a changed login applies at
  /// once.
  final String Function() loginCookie;

  /// Whether the H.265-only qualities of a room page come after its H.264 ones
  /// ("优先 H.264", on by default).
  final bool Function() preferH264;

  /// Injectable clock.
  final DateTime Function() now;

  final Random _random;
  _Browser _browser = _Browser.random(Random());
  _Session? _session;
  Future<_Visit?>? _bootstrap;
  Future<void> _reported = Future.value();
  final Map<String, ({String cursor, Set<String> listed})?> _areaPages = {};

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => kuaishouManifest;

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

  /// The browser's headers for lists and search (a consistent browser
  /// identity).
  Map<String, String> webHeaders() => {
    ..._browser.headers,
    'accept': KuaishouEndpoints.accept,
    'sec-fetch-dest': 'document',
    'sec-fetch-mode': 'navigate',
    'sec-fetch-site': 'same-origin',
    'sec-fetch-user': '?1',
  };

  /// Room page headers: [webHeaders] with `;q=0.9` on `accept`, and [cookie].
  Map<String, String> pageHeaders(String? cookie) => {
    ...webHeaders(),
    'accept': '${KuaishouEndpoints.accept};q=0.9',
    if (cookie != null && cookie.isNotEmpty) 'cookie': cookie,
  };

  /// Search headers: [webHeaders] with the search page as the Referer.
  Map<String, String> searchHeaders(String keyword) => {
    ...webHeaders(),
    'referer': KuaishouEndpoints.searchReferer(keyword),
  };

  // Session -------------------------------------------------------------------

  /// The user's cookie ('' when signed out), control characters and a pasted
  /// `Cookie:` prefix stripped.
  String login() {
    final raw = loginCookie();
    final stripped = String.fromCharCodes(raw.codeUnits.where((unit) => unit >= 0x20 && unit != 0x7F)).trim();
    return stripped.toLowerCase().startsWith('cookie:') ? stripped.substring(7).trim() : stripped;
  }

  /// The anonymous session's cookie header while it is younger than 30 minutes,
  /// else null.
  String? _sessionCookie() {
    final session = _session;
    if (session == null) return null;
    if (now().difference(session.since) < _sessionLifetime) return session.header;
    _session = null;
    return null;
  }

  /// Makes sure an anonymous session exists: a bare GET of the room page [url]
  /// as a new browser, whose `Set-Cookie` becomes the session, then the
  /// best-effort report of its `did`. Concurrent callers share one bootstrap.
  ///
  /// Returns that visit when it was of [url] (it is the room page itself, which
  /// [_roomPage] reads before asking again), else null. The visit does not wait
  /// for the report.
  Future<_Visit?> _ensureSession(Uri url) async {
    if (_sessionCookie() != null) return null;
    final visit = await (_bootstrap ??= () async {
      try {
        _browser = _Browser.random(_random);
        final response = await http.get(url, headers: pageHeaders(null));
        final cookies = KuaishouRoomParser.sessionCookies(response.headers);
        if (cookies.isNotEmpty) {
          _session = _Session(cookies, now());
          final did = cookies['did'];
          if (did != null) _reported = _reportDevice(did);
        }
        return _Visit(url, response);
      } finally {
        _bootstrap = null;
      }
    }());
    return visit != null && visit.url == url ? visit : null;
  }

  /// POSTs the `misc2` report of [did]; failures are ignored (the room page
  /// decides). The session cookie stays with the live host.
  Future<void> _reportDevice(String did) async {
    try {
      await http.postJson(
        KuaishouEndpoints.deviceReport,
        json: KuaishouRoomParser.devicePayload(
          did,
          timestamp: now().millisecondsSinceEpoch,
          incrementId: _random.nextInt(8999) + 1000,
        ),
        headers: {..._browser.headers, 'origin': KuaishouEndpoints.origin, 'referer': '${KuaishouEndpoints.origin}/'},
      );
    } on KuaishouFailure {
      // Best effort.
    }
  }

  /// GETs the room page of [id] and hands it to [parse] with the cookie it
  /// carried.
  ///
  /// A user cookie goes alone, without a session or a retry; a refusal is the
  /// cookie's (risk control). Anonymous pages carry the live session; with
  /// [ensureSession] one is made first. A refused or unreadable page (risk
  /// control, api-changed) drops the session, makes a new one and is retried
  /// once.
  Future<T> _roomPage<T>(
    String id,
    T Function(KuaishouResponse response, {required String cookie, required bool userCookie}) parse, {
    required bool ensureSession,
  }) async {
    final url = KuaishouEndpoints.roomPage(id);
    final login = this.login();
    if (login.isNotEmpty) {
      return parse(await http.get(url, headers: pageHeaders(login)), cookie: login, userCookie: true);
    }
    var visit = ensureSession ? await _ensureSession(url) : null;
    for (var attempt = 0; ; attempt++) {
      if (visit != null) {
        try {
          return parse(visit.page, cookie: _sessionCookie() ?? '', userCookie: false);
        } on KuaishouFailure {
          // The page with the session decides, as before.
        }
      }
      await _reported;
      final cookie = _sessionCookie();
      final response = await http.get(url, headers: pageHeaders(cookie));
      try {
        return parse(response, cookie: cookie ?? '', userCookie: false);
      } on KuaishouFailure catch (failure) {
        final retryable =
            failure.kind == KuaishouFailureKind.riskControl || failure.kind == KuaishouFailureKind.apiChanged;
        if (attempt > 0 || !retryable) rethrow;
      }
      _session = null;
      visit = await _ensureSession(url);
    }
  }

  /// The room with its streams and danmaku arguments, after making sure of a
  /// session; the stream handle and the feed arguments ride in its
  /// [RoomRuntime] handles.
  Future<LiveRoom> detail(String roomId) async {
    final id = roomId.trim();
    if (id.isEmpty) throw const KuaishouFailure(KuaishouFailureKind.notFound, 'empty room id');
    final result = await _roomPage(
      id,
      (response, {required cookie, required userCookie}) => (
        parse: KuaishouRoomParser.roomDetail(
          response.text,
          requestedId: id,
          status: response.status,
          userCookie: userCookie,
        ),
        cookie: cookie,
      ),
      ensureSession: true,
    );
    final parse = result.parse;
    final liveStreamId = parse.liveStreamId;
    return parse.room.copyWith(
      runtime: RoomRuntime(
        streamHandle: KuaishouRoomData(issuedAt: now(), liveStreamId: liveStreamId, playUrls: parse.playUrls),
        danmakuHandle: liveStreamId == null
            ? null
            : KuaishouDanmakuArgs(liveStreamId: liveStreamId, cookie: result.cookie),
      ),
    );
  }

  // Catalog and search --------------------------------------------------------

  /// The home list: one page (every page is answered with it), one card per
  /// streamer.
  Future<List<LiveRoom>> recommend(int page) async {
    if (page > 1) return const [];
    final response = await http.get(KuaishouEndpoints.homeList(), headers: webHeaders());
    return KuaishouRoomParser.recommendRooms(response.text, status: response.status);
  }

  /// The streamer search (a blank keyword gives nothing without a request).
  Future<List<LiveRoom>> search(String keyword, int page) async {
    final text = keyword.trim();
    if (text.isEmpty) return const [];
    final number = page < 1 ? 1 : page;
    final response = await http.get(KuaishouEndpoints.searchAuthor(text, number), headers: searchHeaders(text));
    return KuaishouRoomParser.searchRooms(response.text, status: response.status);
  }

  /// The areas of one top category: pages follow `hasMore`, and a page with
  /// nothing new ends the category (a server repeating a page cannot loop it).
  Future<List<LiveArea>> categoryAreas(String id, String name) async {
    final areas = <String, LiveArea>{};
    for (var page = 1; ; page++) {
      final response = await http.get(KuaishouEndpoints.categoryData(id, page), headers: webHeaders());
      final result = KuaishouRoomParser.areas(
        response.text,
        categoryId: id,
        categoryName: name,
        status: response.status,
      );
      var added = false;
      for (final area in result.areas) {
        if (areas.containsKey(area.areaId)) continue;
        areas[area.areaId] = area;
        added = true;
      }
      if (!result.hasMore || !added) return [...areas.values];
    }
  }

  /// Rooms of one area page. An id shorter than 7 characters is a game board,
  /// the rest non-gameboard, 20 a page; a non-gameboard page after the first
  /// sends the previous page's cursor (kept here, by `areaId#page`, with the
  /// identities listed before it). A room listed on an earlier page is left
  /// out (the live ranking shifts between requests); reading page 1 starts
  /// over, and a page past the last is empty without a request.
  Future<({List<LiveRoom> rooms, bool hasMore})> areaPage(String areaId, int page) async {
    var cursor = '';
    var listed = const <String>{};
    if (page > 1) {
      final key = '$areaId#$page';
      if (!_areaPages.containsKey(key)) await areaPage(areaId, page - 1);
      final stored = _areaPages[key];
      if (!_areaPages.containsKey(key) || stored == null) return (rooms: const <LiveRoom>[], hasMore: false);
      cursor = stored.cursor;
      listed = stored.listed;
    }
    final response = await http.get(KuaishouEndpoints.areaRooms(areaId, page, cursor: cursor), headers: webHeaders());
    final result = KuaishouRoomParser.areaRooms(response.text, status: response.status);
    final seen = {...listed};
    final rooms = [
      for (final room in result.rooms)
        if (seen.add(room.roomId)) room,
    ];
    final next = '$areaId#${page + 1}';
    _areaPages
      ..remove(next)
      ..[next] = result.hasMore ? (cursor: result.cursor ?? '', listed: Set.unmodifiable(seen)) : null;
    if (_areaPages.length > 256) _areaPages.remove(_areaPages.keys.first);
    return (rooms: rooms, hasMore: result.hasMore);
  }

  // Capability wiring ---------------------------------------------------------

  KuaishouRoomProvider? _room;
  KuaishouAreaProvider? _area;
  KuaishouDiscoveryProvider? _discovery;
  KuaishouSearchProvider? _search;
  KuaishouPlaybackProvider? _playback;
  KuaishouDanmakuProvider? _danmaku;
  KuaishouLinkResolver? _link;

  /// The capability of type [T], or null when kuaishou does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= KuaishouRoomProvider(site: this);
    final area = _area ??= KuaishouAreaProvider(site: this);
    final discovery = _discovery ??= KuaishouDiscoveryProvider(site: this);
    final search = _search ??= KuaishouSearchProvider(site: this);
    final playback = _playback ??= KuaishouPlaybackProvider(site: this);
    final danmaku = _danmaku ??= KuaishouDanmakuProvider(site: this);
    final link = _link ??= KuaishouLinkResolver(site: this);
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

/// A session's first visit: the room page it was made on.
final class _Visit {
  _Visit(this.url, this.page);

  final Uri url;
  final KuaishouResponse page;
}

/// The anonymous session: the room page's cookies and when they came.
final class _Session {
  _Session(this.cookies, this.since);

  final Map<String, String> cookies;
  final DateTime since;

  String get header => [for (final entry in cookies.entries) '${entry.key}=${entry.value}'].join('; ');
}

/// A desktop browser identity (a User-Agent and the client hints it sends with
/// every request), picked at random so lists, search and room pages look like a
/// real browser; the version is Chrome-reduction style (`<major>.0.0.0`).
final class _Browser {
  _Browser(this.userAgent, this.clientHints);

  /// A random Chrome identity among Windows, macOS and Linux.
  factory _Browser.random(Random random) {
    const majors = [132, 133, 134, 135, 136, 137, 138];
    const platforms = [
      ('Windows NT 10.0; Win64; x64', 'Windows'),
      ('Macintosh; Intel Mac OS X 10_15_7', 'macOS'),
      ('X11; Linux x86_64', 'Linux'),
    ];
    final major = majors[random.nextInt(majors.length)];
    final (os, label) = platforms[random.nextInt(platforms.length)];
    return _Browser('Mozilla/5.0 ($os) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$major.0.0.0 Safari/537.36', {
      'sec-ch-ua': '"Chromium";v="$major", "Google Chrome";v="$major", "Not?A_Brand";v="24"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"$label"',
    });
  }

  /// The `User-Agent` header value.
  final String userAgent;

  /// The `sec-ch-ua*` hints matching [userAgent].
  final Map<String, String> clientHints;

  /// [userAgent] together with [clientHints].
  Map<String, String> get headers => {'user-agent': userAgent, ...clientHints};
}
