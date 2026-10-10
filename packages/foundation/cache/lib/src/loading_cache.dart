// Module: lib/src/loading_cache.dart
// Purpose: A typed cache that loads on miss, joins concurrent loads for one key, and counts what it did.
// Author: liuchuancong
// Created: 2026-10-11
//
// The value of this class over reading a NamespaceCache by hand is the second sentence: a screen that builds
// fifty tiles at once asks for the same room detail fifty times, and without coalescing that is fifty network
// round trips for one answer. The budget, ttl and eviction stay in NamespaceCache, which already owns them.

import 'dart:convert';

import 'package:pure_live_utils/pure_live_utils.dart';

import 'cache_stats.dart';
import 'policy.dart';
import 'store.dart';

/// Loads what is missing, one load per key at a time.
final class LoadingCache<K, V> {
  LoadingCache({
    required NamespaceCache store,
    required Future<V> Function(K key) loader,
    required int Function(V value) bytesOf,
    this.keyOf,
    this.onEvicted,
    Clock? clock,
  }) : _store = store,
       _loader = loader,
       _bytesOf = bytesOf,
       _clock = clock ?? systemClock;

  final NamespaceCache _store;
  final Future<V> Function(K key) _loader;
  final int Function(V value) _bytesOf;

  /// How a key becomes a cache key. Defaults to `toString`, which is wrong for a key type whose `toString`
  /// is `Instance of ...`, so a caller with such a key must supply one.
  final String Function(K key)? keyOf;

  /// Called for each key the budget evicted, so a caller holding a widget-level reference can drop it.
  final void Function(String key)? onEvicted;

  final Clock _clock;

  final CacheStats stats = CacheStats();

  final Map<String, Future<V>> _inFlight = <String, Future<V>>{};

  String _cacheKey(K key) => keyOf?.call(key) ?? '$key';

  /// The stored value without loading, or null when absent or expired.
  V? getIfPresent(K key) {
    final value = _store.read(_cacheKey(key));
    if (value is V) {
      stats.hits++;
      return value;
    }
    if (value != null) {
      // A value of the wrong type under a live key means two caches share one namespace with colliding keys.
      // Reported rather than served, because serving it produces a cast error somewhere far from here.
      stats.misses++;
      return null;
    }
    stats.misses++;
    return null;
  }

  /// The stored value, or the result of [loader] - which runs at most once per key at a time.
  ///
  /// [refresh] skips the cache and replaces the entry when the load succeeds, keeping the old value until
  /// then: a pull-to-refresh that blanks a list while it reloads is worse than one that shows last known data.
  Future<V> getOrLoad(K key, {bool refresh = false}) {
    final cacheKey = _cacheKey(key);
    if (!refresh) {
      final present = getIfPresent(key);
      if (present != null) {
        return Future<V>.value(present);
      }
    }
    final running = _inFlight[cacheKey];
    if (running != null) {
      stats.coalesced++;
      return running;
    }
    final load = _run(key, cacheKey);
    _inFlight[cacheKey] = load;
    return load;
  }

  Future<V> _run(K key, String cacheKey) async {
    final started = _clock();
    stats.loads++;
    try {
      final value = await _loader(key);
      stats.totalLoadTime += _clock().toUtc().difference(started.toUtc());
      put(key, value);
      return value;
    } on Object {
      stats.loadFailures++;
      rethrow;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  /// Stores [value] under [key], recording whatever the budget evicted to make room.
  void put(K key, V value) {
    final bytes = _bytesOf(value);
    final evicted = _store.write(_cacheKey(key), value, bytes: bytes < 1 ? 1 : bytes);
    stats.bytesWritten += bytes;
    if (evicted.isNotEmpty) {
      stats.evictions += evicted.length;
      for (final gone in evicted) {
        onEvicted?.call(gone);
      }
    }
  }

  /// Drops one key.
  bool invalidate(K key) => _store.remove(_cacheKey(key));

  /// Drops every key [test] accepts, answering how many went.
  ///
  /// Keys are compared as their cache form, so a caller that needs the typed key back must have supplied
  /// [keyOf] and keep its own index - a cache that stores values is not an index of them.
  int invalidateWhere(bool Function(String cacheKey) test) {
    var removed = 0;
    for (final key in _store.keys.toList(growable: false)) {
      if (test(key) && _store.remove(key)) {
        removed++;
      }
    }
    return removed;
  }

  /// Drops everything in the namespace.
  void clear() => _store.clear();

  /// The namespace's current usage, which is what a "cache size" row in settings should show.
  CacheUsage usage() => _store.usage();
}

/// A loader for JSON documents: decodes on the way in and refuses a body that is not the expected shape.
///
/// Kept beside [LoadingCache] because the alternative is every consumer writing the same `jsonDecode` plus
/// `is Map` check, and the version that forgets the check turns a CDN error page into a cast exception three
/// layers up.
final class JsonDocumentLoader {
  const JsonDocumentLoader(this.fetch);

  /// Returns the raw body text for a key; the loader does the decoding and the shape check.
  final Future<String> Function(String key) fetch;

  Future<Map<String, Object?>> load(String key) async {
    final body = await fetch(key);
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (error) {
      throw CacheLoadFailure('the answer for $key was not json', cause: error);
    }
    if (decoded is! Map) {
      throw CacheLoadFailure('the answer for $key was ${decoded.runtimeType}, not an object');
    }
    return Map<String, Object?>.from(decoded);
  }
}

/// A load that could not produce a value.
///
/// Named so a caller can tell "the origin refused" from "the origin answered something we cannot use", which
/// is the difference between retrying and reporting a broken source.
final class CacheLoadFailure extends DomainFailure {
  const CacheLoadFailure(super.reason, {super.cause});
}
