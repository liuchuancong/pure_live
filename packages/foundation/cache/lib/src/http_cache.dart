// Module: lib/src/http_cache.dart
// Purpose: A byte cache that obeys what the origin said, revalidates with conditional requests, and serves
// stale only where the response allowed it.
// Author: liuchuancong
// Created: 2026-10-11
//
// The freshness arithmetic lives in cache_control.dart; this file is the storage and the fetch choreography
// around it. It does not perform requests itself - a caller supplies the fetch - because the transport is
// another L0 package and neither may import the other.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import 'cache_control.dart';
import 'cache_stats.dart';
import 'loading_cache.dart';
import 'policy.dart';
import 'store.dart';

/// One stored response.
final class HttpCacheEntry {
  const HttpCacheEntry({required this.url, required this.bytes, required this.facts});

  final String url;
  final Uint8List bytes;
  final StoredResponseFacts facts;

  int get byteLength => bytes.lengthInBytes;

  /// The body as text, for JSON and playlist bodies.
  String get bodyText => utf8.decode(bytes, allowMalformed: true);

  Map<String, Object?> toJson() => <String, Object?>{
    'url': url,
    'storedAt': facts.storedAt.toUtc().toIso8601String(),
    'bytes': byteLength,
    if (facts.etag != null) 'etag': facts.etag,
    if (facts.lastModified != null) 'lastModified': facts.lastModified!.toUtc().toIso8601String(),
    'control': facts.control.toString(),
  };
}

/// What one fetch answered.
final class HttpFetchOutcome {
  const HttpFetchOutcome({required this.statusCode, required this.headers, this.bytes});

  /// A 304 carries no body and means "what you have is still right".
  final int statusCode;
  final Map<String, String> headers;
  final Uint8List? bytes;

  bool get isNotModified => statusCode == 304;
  bool get isUsable => statusCode >= 200 && statusCode < 300 && bytes != null;

  String? header(String name) {
    final wanted = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == wanted) {
        return entry.value;
      }
    }
    return null;
  }
}

/// One cache lookup, with the verdict that goes with it.
final class HttpCacheRead {
  const HttpCacheRead({required this.entry, required this.decision, required this.fromNetwork});

  final HttpCacheEntry entry;
  final CacheDecision decision;

  /// True when the bytes came from a fetch in this call rather than from the store.
  final bool fromNetwork;

  bool get mayServeWithoutNetwork => decision.mayServeWithoutNetwork;

  @override
  String toString() =>
      'HttpCacheRead(${entry.url}, ${decision.verdict.name}, '
      '${fromNetwork ? 'network' : 'cache'}, ${entry.byteLength}B)';
}

/// A byte cache keyed by url, driven by the origin's own cache directives.
final class HttpCache {
  HttpCache({
    required NamespaceCache store,
    this.defaultLifetime,
    this.isSharedCache = false,
    this.serveStaleOnError = true,
    Clock? clock,
  }) : _store = store,
       _clock = clock ?? systemClock;

  final NamespaceCache _store;

  /// Applied when a response states no lifetime at all. Null means "revalidate every time", which is the safe
  /// reading: guessing a lifetime for an endpoint that never gave one is how a stale room list survives.
  final Duration? defaultLifetime;

  /// Whether this cache is shared between users, which makes `private` responses unstoreable.
  final bool isSharedCache;

  /// Whether a revalidation failure may be answered from the stale copy.
  ///
  /// On by default because the alternative turns a flaky network into an empty screen, and the stale bytes
  /// are what the user was already looking at. Turn it off for a cache whose correctness matters more than
  /// its availability - a signed stream url, for one.
  final bool serveStaleOnError;

  final Clock _clock;

  final CacheStats stats = CacheStats();

  final Map<String, Future<HttpCacheRead>> _inFlight = <String, Future<HttpCacheRead>>{};

  /// The key one url is stored under.
  ///
  /// Hashed because a url is unbounded and can carry characters a filename or a JSON key should not; the
  /// mapping is one-way, so the entry keeps the url it was fetched from.
  static String keyFor(String url) => sha256.convert(utf8.encode(url)).toString();

  /// What is stored for [url], with the verdict for right now, or null when nothing is stored.
  HttpCacheRead? peek(String url) {
    final stored = _store.read(keyFor(url));
    if (stored is! HttpCacheEntry) {
      return null;
    }
    final decision = decideCacheUse(stored.facts, now: _clock(), defaultLifetime: defaultLifetime);
    return HttpCacheRead(entry: stored, decision: decision, fromNetwork: false);
  }

  /// The bytes for [url]: from the store when the origin's directives allow it, otherwise from [fetch].
  ///
  /// Concurrent calls for one url share a single fetch, so a grid of fifty tiles that all want the same
  /// playlist costs one request rather than fifty.
  Future<HttpCacheRead> read(
    String url,
    Future<HttpFetchOutcome> Function(Map<String, String> headers) fetch, {
    bool refresh = false,
  }) {
    final cacheKey = keyFor(url);
    final running = _inFlight[cacheKey];
    if (running != null) {
      stats.coalesced++;
      return running;
    }
    final work = _read(url, cacheKey, fetch, refresh: refresh);
    _inFlight[cacheKey] = work;
    // The entry is removed when the future settles, not before: a caller awaiting it must not be joined to a
    // load that has already finished and been forgotten.
    work.whenComplete(() {
      if (identical(_inFlight[cacheKey], work)) {
        _inFlight.remove(cacheKey);
      }
    });
    return work;
  }

  Future<HttpCacheRead> _read(
    String url,
    String cacheKey,
    Future<HttpFetchOutcome> Function(Map<String, String> headers) fetch, {
    required bool refresh,
  }) async {
    final existing = peek(url);
    if (existing != null && !refresh) {
      switch (existing.decision.verdict) {
        case CacheVerdict.fresh:
          stats.hits++;
          stats.bytesRead += existing.entry.byteLength;
          return existing;
        case CacheVerdict.staleUsable:
          // Serve now, refresh behind the caller. The refresh is deliberately not awaited: the whole point of
          // stale-while-revalidate is that the user does not wait for it.
          stats.staleServed++;
          stats.hits++;
          unawaited(_refreshQuietly(url, fetch));
          return existing;
        case CacheVerdict.revalidate:
        case CacheVerdict.staleForErrorOnly:
          stats.misses++;
          return _revalidate(url, existing, fetch, allowStale: true);
        case CacheVerdict.unusable:
          stats.misses++;
          break;
      }
    } else {
      stats.misses++;
    }

    final outcome = await _fetch(url, fetch, const <String, String>{});
    if (!outcome.isUsable) {
      if (existing != null && serveStaleOnError) {
        stats.staleServedOnError++;
        return HttpCacheRead(entry: existing.entry, decision: existing.decision, fromNetwork: false);
      }
      throw CacheLoadFailure('the origin answered ${outcome.statusCode} for $url');
    }
    final entry = _persist(url, cacheKey, outcome);
    return HttpCacheRead(
      entry: entry,
      decision: decideCacheUse(entry.facts, now: _clock(), defaultLifetime: defaultLifetime),
      fromNetwork: true,
    );
  }

  Future<HttpCacheRead> _revalidate(
    String url,
    HttpCacheRead existing,
    Future<HttpFetchOutcome> Function(Map<String, String> headers) fetch, {
    required bool allowStale,
  }) async {
    final headers = revalidationHeaders(existing.entry.facts);
    final HttpFetchOutcome outcome;
    try {
      outcome = await _fetch(url, fetch, headers);
    } on Object catch (error) {
      if (allowStale && serveStaleOnError) {
        stats.staleServedOnError++;
        return HttpCacheRead(entry: existing.entry, decision: existing.decision, fromNetwork: false);
      }
      throw CacheLoadFailure('revalidation of $url failed', cause: error);
    }

    if (outcome.isNotModified) {
      // 304 means the stored body is still the right one; only the freshness facts move forward. A cache that
      // treated 304 as "no answer" would re-download the body it just proved it already has.
      final refreshed = _storeFacts(existing.entry, outcome);
      return HttpCacheRead(
        entry: refreshed,
        decision: decideCacheUse(refreshed.facts, now: _clock(), defaultLifetime: defaultLifetime),
        fromNetwork: false,
      );
    }
    if (!outcome.isUsable) {
      if (allowStale && serveStaleOnError) {
        stats.staleServedOnError++;
        return HttpCacheRead(entry: existing.entry, decision: existing.decision, fromNetwork: false);
      }
      throw CacheLoadFailure('revalidation of $url answered ${outcome.statusCode}');
    }
    final entry = _persist(url, keyFor(url), outcome);
    return HttpCacheRead(
      entry: entry,
      decision: decideCacheUse(entry.facts, now: _clock(), defaultLifetime: defaultLifetime),
      fromNetwork: true,
    );
  }

  Future<void> _refreshQuietly(String url, Future<HttpFetchOutcome> Function(Map<String, String>) fetch) async {
    try {
      final existing = peek(url);
      if (existing == null) {
        return;
      }
      await _revalidate(url, existing, fetch, allowStale: false);
    } on Object {
      // A background refresh that fails leaves the served copy alone; the next read tries again.
    }
  }

  Future<HttpFetchOutcome> _fetch(
    String url,
    Future<HttpFetchOutcome> Function(Map<String, String> headers) fetch,
    Map<String, String> headers,
  ) async {
    stats.loads++;
    final started = _clock();
    try {
      final outcome = await fetch(headers);
      stats.totalLoadTime += _clock().toUtc().difference(started.toUtc());
      return outcome;
    } on Object {
      stats.loadFailures++;
      rethrow;
    }
  }

  HttpCacheEntry _persist(String url, String cacheKey, HttpFetchOutcome outcome) {
    final bytes = outcome.bytes ?? Uint8List(0);
    final entry = HttpCacheEntry(url: url, bytes: bytes, facts: _factsOf(outcome));
    final evicted = _store.write(cacheKey, entry, bytes: bytes.lengthInBytes < 1 ? 1 : bytes.lengthInBytes);
    stats.bytesWritten += bytes.lengthInBytes;
    if (evicted.isNotEmpty) {
      stats.evictions += evicted.length;
    }
    return entry;
  }

  HttpCacheEntry _storeFacts(HttpCacheEntry entry, HttpFetchOutcome outcome) {
    final facts = _factsOf(outcome, storedAt: entry.facts.storedAt);
    final refreshed = HttpCacheEntry(url: entry.url, bytes: entry.bytes, facts: facts);
    _store.write(keyFor(entry.url), refreshed, bytes: refreshed.byteLength < 1 ? 1 : refreshed.byteLength);
    return refreshed;
  }

  StoredResponseFacts _factsOf(HttpFetchOutcome outcome, {DateTime? storedAt}) => StoredResponseFacts(
    storedAt: (storedAt ?? _clock()).toUtc(),
    control: CacheControl.parse(outcome.header('cache-control')),
    dateHeader: parseHttpDate(outcome.header('date')),
    expiresHeader: parseHttpDate(outcome.header('expires')),
    etag: outcome.header('etag'),
    lastModified: parseHttpDate(outcome.header('last-modified')),
    isSharedCache: isSharedCache,
  );

  /// Drops one url.
  bool invalidate(String url) => _store.remove(keyFor(url));

  /// Drops every entry for one host, which is what "this source is misbehaving, forget what it told us" means.
  int invalidateHost(String host) {
    var removed = 0;
    for (final key in _store.keys.toList(growable: false)) {
      final stored = _store.read(key);
      if (stored is HttpCacheEntry && Uri.tryParse(stored.url)?.host == host) {
        if (_store.remove(key)) {
          removed++;
        }
      }
    }
    return removed;
  }

  /// Empties the namespace.
  void clear() => _store.clear();

  /// The namespace's usage, for a settings screen that has to say how much room the cache takes.
  CacheUsage usage() => _store.usage();
}
