// Module: lib/src/store.dart
// Purpose: A bounded, namespaced cache with ttl and eviction, shared by every consumer that would otherwise keep its own.
// Author: liuchuancong
// Created: 2026-10-08
//
// docs/services/cache.md: caches are a foundation capability, namespaces are fixed, and one plugin must
// not be able to read or clear another's entries. The hub therefore hands out a NamespaceCache bound to
// exactly one namespace: there is no method on it that takes a namespace argument.
//
// This is the in-memory tier. A disk tier plugs in behind it with the same shape; the point of putting
// the policy here is that both tiers agree on what "over quota" means.

import 'package:pure_live_utils/pure_live_utils.dart';

import 'policy.dart';

class _CacheEntry {
  _CacheEntry({required this.key, required this.value, required this.bytes, required DateTime at})
    : storedAt = at.toUtc(),
      lastUsedAt = at.toUtc();

  final String key;
  final Object? value;
  final int bytes;
  final DateTime storedAt;
  DateTime lastUsedAt;
}

/// A cache scoped to a single namespace.
final class NamespaceCache {
  NamespaceCache._({required this.namespace, required this.policy, required this.clock});

  final CacheNamespace namespace;
  final CachePolicy policy;
  final Clock clock;

  final Map<String, _CacheEntry> _entries = <String, _CacheEntry>{};

  /// Number of entries currently held, including any that are expired but not yet touched.
  int get length => _entries.length;

  /// The cached value for [key], or null when absent or past its ttl.
  ///
  /// Reading refreshes the recency stamp, which is what LRU eviction orders on.
  Object? read(String key) {
    final entry = _entries[key];
    if (entry == null) {
      return null;
    }
    if (_isStale(entry)) {
      _entries.remove(key);
      return null;
    }
    entry.lastUsedAt = clock().toUtc();
    return entry.value;
  }

  /// Stores [value] under [key]. [bytes] is supplied by the caller because only the caller knows how
  /// expensive the object is; a plain object reference is not a useful measure.
  ///
  /// Returns the entries evicted to stay inside the policy, so a caller can log or meter the pressure.
  List<String> write(String key, Object? value, {int bytes = 1}) {
    _entries[key] = _CacheEntry(key: key, value: value, bytes: bytes < 0 ? 0 : bytes, at: clock());
    return _enforceLimits();
  }

  /// Removes one entry, returning whether it was there.
  bool remove(String key) => _entries.remove(key) != null;

  /// Drops every entry in this namespace and nothing else.
  void clear() => _entries.clear();

  List<String> get keys => _entries.keys.toList(growable: false);

  CacheUsage usage() => CacheUsage(namespace: namespace, entries: _entries.length, bytes: _totalBytes());

  bool _isStale(_CacheEntry entry) {
    final ttl = policy.ttl;
    if (ttl == null) {
      return false;
    }
    return !clock().toUtc().isBefore(entry.storedAt.add(ttl));
  }

  int _totalBytes() => _entries.values.fold<int>(0, (sum, entry) => sum + entry.bytes);

  List<String> _enforceLimits() {
    final evicted = <String>[];
    while (_entries.isNotEmpty && (_totalBytes() > policy.maxBytes || _entries.length > policy.maxEntries)) {
      final victim = _pickVictim();
      if (victim == null) {
        break;
      }
      _entries.remove(victim.key);
      evicted.add(victim.key);
    }
    return evicted;
  }

  _CacheEntry? _pickVictim() {
    if (_entries.isEmpty) {
      return null;
    }
    final ordered = _entries.values.toList(growable: false);
    if (policy.eviction == CacheEviction.firstInFirstOut) {
      ordered.sort((a, b) => a.storedAt.compareTo(b.storedAt));
    } else {
      ordered.sort((a, b) => a.lastUsedAt.compareTo(b.lastUsedAt));
    }
    return ordered.first;
  }
}

/// Owns the namespaces and their policies.
final class CacheHub {
  CacheHub({
    Map<CacheNamespace, CachePolicy> policies = const <CacheNamespace, CachePolicy>{},
    this.defaultPolicy = const CachePolicy(),
    Clock? clock,
  }) : _clock = clock ?? systemClock {
    _resolved = <CacheNamespace, CachePolicy>{
      for (final namespace in CacheNamespace.values) namespace: policies[namespace] ?? defaultPolicy,
    };
    for (final namespace in CacheNamespace.values) {
      _caches[namespace] = NamespaceCache._(namespace: namespace, policy: _resolved[namespace]!, clock: _clock);
    }
  }

  final CachePolicy defaultPolicy;
  final Clock _clock;
  final Map<CacheNamespace, NamespaceCache> _caches = <CacheNamespace, NamespaceCache>{};
  late final Map<CacheNamespace, CachePolicy> _resolved;

  /// The cache for [namespace]. There is no way to address another namespace through it.
  NamespaceCache of(CacheNamespace namespace) => _caches[namespace]!;

  CachePolicy policyFor(CacheNamespace namespace) => _resolved[namespace]!;

  /// Usage of every namespace, in declaration order, for the settings screen.
  List<CacheUsage> usage() =>
      CacheNamespace.values.map((namespace) => _caches[namespace]!.usage()).toList(growable: false);

  /// Total bytes held across all namespaces.
  int get totalBytes => usage().fold<int>(0, (sum, item) => sum + item.bytes);

  void clearAll() {
    for (final cache in _caches.values) {
      cache.clear();
    }
  }
}
