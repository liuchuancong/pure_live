import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart' as dio;
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:live_log/live_log.dart' show LiveLog;

import 'package:live_net/src/client_profile.dart';
import 'package:live_net/src/dio_http.dart';
import 'package:live_net/src/live_http.dart';
import 'package:live_net/src/proxy.dart';

/// Assembles [LiveHttp] instances from a [ClientProfile] plus the shared
/// parts the app shell provides (log target, cache store, cookie jar,
/// proxy policy).
///
/// The factory owns the per-profile defaults — what may be cached, how
/// often a call may retry — so business modules never touch interceptor
/// settings. One instance per profile is created and reused; inject a
/// [CacheStore] and [CookieJar] from outside (file directories come from
/// the app shell, via path_provider or portable-mode paths).
final class DioFactory {
  /// A factory sharing [cacheStore] (defaults to memory), [cookieJar]
  /// (defaults to an in-memory jar), [proxyPolicy], [defaultHeaders] and
  /// the network [log] across every client it builds. [adapterFactory]
  /// lets the app shell plug platform-native HTTP stacks (a Flutter
  /// plugin such as native_dio_adapter) without making this package
  /// Flutter-bound; built-in selection keeps dart:io, with optional
  /// HTTP/2 for direct routes.
  new({
    this.log,
    this.cacheStore,
    this.cookieJar,
    this.proxyPolicy,
    Map<String, String> defaultHeaders = const {},
    this.adapterFactory,
    this.useHttp2 = false,
  }) : _defaultHeaders = Map.of(defaultHeaders);

  /// Network log target, or null to keep the pipeline silent.
  final LiveLog? log;

  /// The cache store behind every profile; defaults to an in-memory LRU.
  final CacheStore? cacheStore;

  /// The session cookie jar; defaults to an in-memory jar.
  final CookieJar? cookieJar;

  /// Per-request routing decisions, or null for direct traffic.
  final ProxyPolicy? proxyPolicy;

  late final CacheStore _effectiveCacheStore = cacheStore ?? MemCacheStore();
  late final CookieJar _effectiveCookieJar = cookieJar ?? CookieJar();
  final Map<String, String> _defaultHeaders;

  /// Whether direct routes should speak HTTP/2.
  final bool useHttp2;

  /// Injectable adapter hook forwarded to every built client.
  final dio.HttpClientAdapter? Function(ProxyRoute route)? adapterFactory;

  final Map<ClientProfile, LiveHttp> _clients = {};

  /// The [LiveHttp] for [profile]; repeated calls return the same instance.
  LiveHttp create({ClientProfile profile = ClientProfile.site}) => _clients.putIfAbsent(profile, () => _build(profile));

  /// Drops every cached response across all profiles — account switches,
  /// logouts and site removals go through here.
  Future<void> purgeCache() => _effectiveCacheStore.clean();

  /// Clears every managed session cookie — the logout path.
  Future<void> clearCookies() => _effectiveCookieJar.deleteAll();

  LiveHttp _build(ClientProfile profile) => DioLiveHttp(
    proxyPolicy: proxyPolicy,
    defaultHeaders: _defaultHeaders,
    log: log,
    cookieJar: _effectiveCookieJar,
    cacheOptions: _cacheOptionsFor(profile),
    maxRetries: _maxRetriesFor(profile),
    adapterFactory: adapterFactory,
    useHttp2: useHttp2,
  );

  /// Cache baseline per profile: `api` and `site` follow HTTP cache
  /// semantics (only requests that explicitly opt in are stored), while
  /// `plugin`, `media` (signed URLs must not land on disk) and `auth`
  /// never cache by default.
  CacheOptions _cacheOptionsFor(ClientProfile profile) => CacheOptions(
    store: _effectiveCacheStore,
    policy: switch (profile) {
      ClientProfile.api || ClientProfile.site => CachePolicy.request,
      ClientProfile.plugin || ClientProfile.media || ClientProfile.auth => CachePolicy.noCache,
    },
  );

  /// Retry budget per profile: auth flows never retry, plugins are
  /// strictly limited, media is cautious, everything idempotent elsewhere
  /// gets a bounded number of attempts (the evaluator still refuses
  /// cancellations, TLS rejections and non-idempotent POSTs).
  int _maxRetriesFor(ClientProfile profile) => switch (profile) {
    ClientProfile.api || ClientProfile.site => 2,
    ClientProfile.media || ClientProfile.plugin => 1,
    ClientProfile.auth => 0,
  };
}
