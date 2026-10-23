import 'dart:async';
import 'dart:math';

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
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:live_sites/src/platforms/bigo/api/bigo_endpoints.dart';
import 'package:live_sites/src/platforms/bigo/api/bigo_http.dart';
import 'package:live_sites/src/platforms/bigo/api/bigo_token.dart';
import 'package:live_sites/src/platforms/bigo/bigo_manifest.dart';
import 'package:live_sites/src/platforms/bigo/capabilities/bigo_area_provider.dart';
import 'package:live_sites/src/platforms/bigo/capabilities/bigo_discovery_provider.dart';
import 'package:live_sites/src/platforms/bigo/capabilities/bigo_link_resolver.dart';
import 'package:live_sites/src/platforms/bigo/capabilities/bigo_playback_provider.dart';
import 'package:live_sites/src/platforms/bigo/capabilities/bigo_room_provider.dart';
import 'package:live_sites/src/platforms/bigo/capabilities/bigo_search_provider.dart';
import 'package:live_sites/src/platforms/bigo/danmaku/bigo_danmaku_session.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_failure.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_room_parser.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_studio.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How a studio answer is asked for, which decides whether the answer can be
/// the one that carries the playlist.
enum BigoStudioUse {
  /// A room read: a fresh token, whose first use says whether the room has a
  /// password and hands out the playlist; a login gate is asked again with the
  /// same token for the state.
  entry,

  /// A quality list or a state check: the reusable token; a login gate is asked
  /// again with the same token and that answer is used.
  refresh,

  /// A play resolve: a fresh token for the playlist, nothing asked again.
  input,
}

/// The Bigo Live adapter (parsing in `parsers/`): manifest + capability
/// discovery + lifecycle (ARCHITECTURE.md §7.2).
///
/// Anonymous, like the website's own player: no cookie and no account. Every
/// request carries [BigoEndpoints.headers] and goes as `bigo`, so the app routes
/// the platform through its proxy setting. The requests:
/// - the catalog, the directory, the recommendations and the search filter are
///   all the one public list `vedioList/72` (about 20 live rooms), paged
///   locally; the first page asks anew and every later call reuses a list
///   younger than [snapshotLifetime], so a directory page and the search that
///   filters it never work on two different lists;
/// - a room is the anonymous web token (`webjs/t`, then `webjs/status` with the
///   encrypted request) and `getInternalStudioInfo` with it, within one
///   [deadline]. Only a token's first use gives the playlist and says whether
///   the room has a password, so a room read and a play resolve take a fresh
///   token (three requests), while a quality list or a state check reuses the
///   last token for [tokenReuse] (one request);
/// - the streams have no URL to keep: the one quality resolves through the
///   studio again on every play, and the playlist's segments are scrambled on
///   their way through a relay (see `BigoHlsProtection`).
///
/// Rooms are identified by the Bigo id the site writes (`clientBigoId`), which
/// is what a detail returns whatever the room was asked for by; list cards keep
/// the list's `bigo_id`. Failures are [BigoFailure]s; nothing is disguised as an
/// offline room.
final class BigoSite implements LiveSite {
  /// Creates the adapter over [http]. [deadline] bounds a list fetch, and a web
  /// token with its studio requests together. [now], [random] (the token
  /// request's salt and nonce) and [callbackName] (the JSONP callback of each
  /// token request) are injectable for tests.
  factory BigoSite({
    required BigoHttp http,
    Duration deadline = const Duration(seconds: 20),
    DateTime Function()? now,
    Random? random,
    String Function()? callbackName,
  }) => BigoSite._(
    http: http,
    deadline: deadline,
    now: now ?? DateTime.now,
    random: random ?? Random.secure(),
    callbackName: callbackName,
  );

  BigoSite._({
    required this.http,
    required this.deadline,
    required this.now,
    required this._random,
    this._callbackName,
  });

  /// Transport.
  final BigoHttp http;

  /// Longest list fetch, or token and studio requests together.
  final Duration deadline;

  /// Injectable clock.
  final DateTime Function() now;

  final Random _random;
  final String Function()? _callbackName;
  Future<List<LiveRoom>>? _snapshot;
  DateTime? _snapshotAt;
  String? _token;
  DateTime? _tokenAt;
  Future<String>? _tokenFetch;

  /// How long a list is reused after it arrived.
  static const Duration snapshotLifetime = Duration(seconds: 30);

  /// How long a web token is reused by quality lists and state checks after it
  /// was issued. The site answers every use of a token after the first the same
  /// way however old it is, so this is a margin, not a measured expiry.
  static const Duration tokenReuse = Duration(minutes: 30);

  /// Stable platform identity.
  @override
  LiveSiteManifest get manifest => bigoManifest;

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
      throw BigoFailure(BigoFailureKind.network, 'no answer within ${deadline.inSeconds} s', cause: failure);
    } finally {
      timer.cancel();
    }
  }

  // Public list ---------------------------------------------------------------

  Future<List<LiveRoom>> _fetchSnapshot(CancelToken token) async {
    final response = await http.get(BigoEndpoints.publicList(), cancel: token);
    return BigoRoomParser.directory(response.text, status: response.status);
  }

  /// The public list.
  ///
  /// [fresh] (the first page of the directory, the pull to refresh) always asks
  /// anew. Otherwise the last list is reused while it is younger than
  /// [snapshotLifetime] after it arrived, whoever fetched it, and a call that
  /// comes while a fetch is under way shares it. The latest successful fetch
  /// becomes the shared list; a failed one is forgotten.
  Future<List<LiveRoom>> snapshot({bool fresh = false}) {
    if (!fresh) {
      final cached = _snapshot;
      final at = _snapshotAt;
      if (cached != null && (at == null || _young(at, snapshotLifetime))) return cached;
    }
    late final Future<List<LiveRoom>> fetch;
    fetch = _scoped(_fetchSnapshot).then(
      (cards) {
        if (identical(_snapshot, fetch)) _snapshotAt = now();
        return cards;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_snapshot, fetch)) {
          _snapshot = null;
          _snapshotAt = null;
        }
        Error.throwWithStackTrace(error, stack);
      },
    );
    _snapshot = fetch;
    _snapshotAt = null;
    return fetch;
  }

  bool _young(DateTime at, Duration lifetime) {
    final age = now().difference(at);
    return age >= Duration.zero && age < lifetime;
  }

  // Web token -----------------------------------------------------------------

  String _callback() {
    final name = _callbackName?.call() ?? BigoToken.callbackName(now());
    if (!BigoToken.isCallbackName(name)) {
      throw BigoFailure(BigoFailureKind.apiChanged, '"$name" is not a JSONP callback name');
    }
    return name;
  }

  /// A new anonymous web token: the server time, then the token for the
  /// encrypted request.
  Future<String> _fetchToken(CancelToken token) async {
    final timeCallback = _callback();
    final time = await http.get(BigoEndpoints.serverTime(timeCallback), cancel: token);
    final timestamp = BigoToken.serverTime(time.text, callback: timeCallback, status: time.status);
    final statusCallback = _callback();
    final status = await http.get(
      BigoEndpoints.tokenRequest(statusCallback, BigoToken.tokenData(timestamp, random: _random)),
      cancel: token,
    );
    return BigoToken.token(status.text, callback: statusCallback, status: status.status);
  }

  /// Keeps [token] for refreshes, from now on for [tokenReuse].
  void _keepToken(String token) {
    _token = token;
    _tokenAt = now();
  }

  /// The token of a refresh: the kept one while younger than [tokenReuse], else
  /// one new token shared by every caller that asks before it arrives (a follow
  /// list refreshes its rooms together). A failed fetch is forgotten.
  Future<String> _reusableToken() {
    final token = _token;
    final at = _tokenAt;
    if (token != null && at != null && _young(at, tokenReuse)) return Future.value(token);
    return _tokenFetch ??= _scoped(_fetchToken).then(
      (token) {
        _keepToken(token);
        _tokenFetch = null;
        return token;
      },
      onError: (Object error, StackTrace stack) {
        _tokenFetch = null;
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  // Studio --------------------------------------------------------------------

  /// `getInternalStudioInfo` of [siteId] with [webToken] (the token in the query
  /// and an empty body).
  Future<BigoStudio> _ask(String siteId, String webToken, CancelToken token) async {
    final studio = await http.post(BigoEndpoints.studio(siteId, webToken), cancel: token);
    return BigoRoomParser.studio(studio.text, requestedSiteId: siteId, status: studio.status);
  }

  /// The studio of [siteId] for [use], within one [deadline].
  ///
  /// A room read and a play resolve take a fresh token (three requests): only a
  /// token's first use gives the playlist and says whether the room has a
  /// password. A refresh takes the reusable token (one request when one is
  /// kept). Every token, once used, is kept for refreshes.
  ///
  /// The site sometimes answers a token's first use with `needLogin`, all
  /// fields zeroed, and turns out to accept the same token a moment later (seen
  /// in bursts of new tokens). The same token asked again (one more request, only
  /// then) gives the room's state: a room read keeps the login gate with that
  /// state (a gated live room is live and marked), a refresh uses that answer as
  /// it is. A play resolve asks nothing again: a gated input has no playlist
  /// either way.
  Future<BigoStudio> studio(String siteId, BigoStudioUse use) => _scoped((token) async {
    final checked = BigoRoomParser.checkedSiteId(siteId);
    final webToken = switch (use) {
      BigoStudioUse.refresh => await _reusableToken(),
      BigoStudioUse.entry || BigoStudioUse.input => await _fetchToken(token),
    };
    final first = await _ask(checked, webToken, token);
    if (use != BigoStudioUse.refresh) _keepToken(webToken);
    if (first.access != BigoAccess.loginRequired || use == BigoStudioUse.input) return first;
    final again = await _ask(checked, webToken, token);
    if (again.access == BigoAccess.loginRequired) {
      if (_token == webToken) _tokenAt = null;
      return first;
    }
    return use == BigoStudioUse.refresh ? again : again.gated();
  });

  /// The room: a fresh web token and the studio. Its id is the site's
  /// `clientBigoId`, whatever id it was asked for by. A live studio whose chat
  /// the website opens carries its chat arguments, and every studio its stream
  /// handle, without another request.
  Future<LiveRoom> detail(String roomId) async {
    final answer = await studio(roomId, BigoStudioUse.entry);
    return BigoRoomParser.room(answer).rebuild(
      (b) => b
        ..runtime = RoomRuntime.of(
          streamHandle: BigoRoomParser.roomData(answer),
          danmakuHandle: BigoRoomParser.danmakuArgs(answer),
        ).toBuilder(),
    );
  }

  /// The studio with the reusable token: one request while a token is kept, the
  /// token's two requests once in [tokenReuse]. The answer of a used token has
  /// the state, names and pictures but neither the playlist nor the password
  /// flag, so it answers a quality list, not a playlist.
  Future<BigoStudio> refresh(String roomId) => studio(roomId, BigoStudioUse.refresh);

  /// The media of a play resolve: a fresh web token and studio answer, never
  /// shared between consumers or reused after a failure, and the playlist as a
  /// line with the platform's headers. A studio that cannot be watched says why;
  /// an answer without the playlist is stream-unavailable.
  Future<Uri> playPlaylist(String roomId) async {
    final answer = await studio(roomId, BigoStudioUse.input);
    final error = answer.streamError;
    if (error != null) throw error;
    final hls = answer.hls;
    if (hls == null) throw BigoFailure(BigoFailureKind.streamUnavailable, '${answer.siteId}: no hls_src');
    return hls;
  }

  // Catalog and search --------------------------------------------------------

  /// Page [page] (20 rooms) of the public list. The first page asks for a new
  /// list; later pages come from the last one, so they neither repeat nor skip
  /// rooms of page one.
  Future<({List<LiveRoom> rooms, bool hasMore})> directory(int page) async =>
      BigoRoomParser.directoryPage(await snapshot(fresh: page <= 1), page: page);

  /// A slice [page] of [pageSize] of the public list (a page or size below 1, or
  /// a size over 100, gives nothing, without a request), from the shared list,
  /// and whether the list has a room past it.
  Future<({List<LiveRoom> rooms, bool hasMore})> recommend(int page, int pageSize) async {
    if (!BigoRoomParser.validSlice(page: page, pageSize: pageSize)) return (rooms: const <LiveRoom>[], hasMore: false);
    final cards = await snapshot();
    return (
      rooms: BigoRoomParser.slice(cards, page: page, pageSize: pageSize),
      hasMore: page * pageSize < cards.length,
    );
  }

  /// The room of [siteId] as one result, or none when the site does not know it.
  Future<List<LiveRoom>> _lookUp(String siteId) async {
    try {
      return [await detail(siteId)];
    } on BigoFailure catch (failure) {
      if (failure.kind != BigoFailureKind.notFound) rethrow;
      return const [];
    }
  }

  /// Bigo's search, first page only (the web search endpoints answer nothing): a
  /// room link is looked up by its id; a keyword that looks like an id is looked
  /// up first; otherwise the public list is filtered by streamer name and topic,
  /// and a word of letters that matches no card is looked up as an id. The
  /// filter uses the list the directory showed while it is still young. A blank,
  /// over-long or control keyword, a URL of another site or another page gives
  /// nothing without a request.
  Future<List<LiveRoom>> search(String keyword, int page, int pageSize) async {
    if (page != 1 || pageSize < 1) return const [];
    final query = keyword.trim();
    final linked = BigoRoomParser.siteIdFromUrl(query);
    if (linked != null) return await _lookUp(linked);
    if (!BigoRoomParser.isSearchable(query)) return const [];
    final siteId = BigoRoomParser.siteIdOf(query);
    final asId = BigoRoomParser.looksLikeId(query);
    if (asId) {
      final exact = await _lookUp(query);
      if (exact.isNotEmpty) return exact;
    }
    final cards = await snapshot();
    final asName = siteId != null && !asId;
    if (asName && cards.any((card) => card.roomId.toLowerCase() == query.toLowerCase())) {
      return await _lookUp(siteId);
    }
    final matches = BigoRoomParser.filter(cards, query);
    if (matches.isNotEmpty) return matches;
    return asName ? await _lookUp(siteId) : const [];
  }

  // Capability wiring ---------------------------------------------------------

  BigoRoomProvider? _room;
  BigoAreaProvider? _area;
  BigoDiscoveryProvider? _discovery;
  BigoSearchProvider? _search;
  BigoPlaybackProvider? _playback;
  BigoDanmakuProvider? _danmaku;
  BigoLinkResolver? _link;

  /// The capability of type [T], or null when bigo does not support it
  /// (ARCHITECTURE.md §4.1). Capabilities are singletons per site.
  @override
  T? capability<T extends LiveSiteCapability>() {
    final room = _room ??= BigoRoomProvider(site: this);
    final area = _area ??= BigoAreaProvider(site: this);
    final discovery = _discovery ??= BigoDiscoveryProvider(site: this);
    final search = _search ??= BigoSearchProvider(site: this);
    final playback = _playback ??= BigoPlaybackProvider(site: this);
    final danmaku = _danmaku ??= BigoDanmakuProvider(site: this);
    final link = _link ??= BigoLinkResolver(site: this);
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
