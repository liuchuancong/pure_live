// Module: lib/src/decorators.dart
// Purpose: Composable store behaviour - owner isolation, expiry, read-through caching, write coalescing and
// batch operations - without a second backend implementation.
// Author: liuchuancong
// Created: 2026-10-11
//
// One JSON file holds several owners' rows, and every feature that learned that the hard way added its own
// prefix rules, its own expiry and its own "write twenty settings, rewrite the file twenty times". These are
// decorators over the same KeyValueStore, so the rules are written once and a store can be assembled per
// caller: namespaced, then expiring, then buffered, over the file.
//
// The composition order matters and is documented on each type: a cache in front of an expiring store serves
// dead rows, and a buffer in front of a cache hides writes from its own reads.

import 'dart:async';
import 'dart:convert';

import 'package:pure_live_utils/pure_live_utils.dart';

import 'stores.dart';

/// The row count a decorator keeps before it flushes or evicts.
const int kStoreDefaultMaxEntries = 256;

/// A [KeyValueStore] view that prefixes every key with [namespace] and only ever touches its own rows.
///
/// The prefix is what stops two owners writing `enabled` to the same file; the reason this is a type rather
/// than a convention is `clear()`: a plain prefixed caller would wipe its siblings' rows, and the store has no
/// way to tell it that it just did.
final class NamespacedKeyValueStore implements KeyValueStore {
  NamespacedKeyValueStore({required KeyValueStore inner, required this.namespace}) : _inner = inner {
    if (namespace.trim().isEmpty || namespace.contains('.')) {
      throw ArgumentError.value(namespace, 'namespace', 'must be a non-blank single segment');
    }
  }

  final KeyValueStore _inner;
  final String namespace;

  String _wrap(String key) => '$namespace.$key';

  String _unwrap(String key) => key.length > namespace.length + 1 ? key.substring(namespace.length + 1) : key;

  @override
  Future<Object?> read(String key) => _inner.read(_wrap(key));

  @override
  Future<void> write(String key, Object? value) => _inner.write(_wrap(key), value);

  @override
  Future<void> remove(String key) => _inner.remove(_wrap(key));

  /// Keys of this namespace only, with the prefix stripped so the caller never sees its own namespace.
  @override
  Future<List<String>> keys() async {
    final all = await _inner.keys();
    return <String>[
      for (final key in all)
        if (key.startsWith('$namespace.')) _unwrap(key),
    ];
  }

  /// This namespace's rows, and nothing else.
  @override
  Future<void> clear() async {
    for (final key in await keys()) {
      await _inner.remove(_wrap(key));
    }
  }

  /// Whether [key] belongs to this namespace as seen from the outside.
  bool owns(String outerKey) => outerKey.startsWith('$namespace.');
}

/// A [KeyValueStore] whose rows expire.
///
/// Wrapped rows become a small envelope (`{"v": ..., "u": <deadline microsecond>}`), so the deadline travels
/// with the value rather than living in a side table a caller must keep in sync. Read a store wrapped by this
/// one *through* it: the envelope is not a plain value any more.
final class ExpiringKeyValueStore implements KeyValueStore {
  ExpiringKeyValueStore({required KeyValueStore inner, Clock? clock, this.defaultTtl, this.maxTtl})
    : _inner = inner,
      _clock = clock ?? systemClock {
    final ttl = defaultTtl;
    if (ttl != null && ttl.isNegative) {
      throw ArgumentError.value(ttl, 'defaultTtl', 'cannot be negative');
    }
  }

  final KeyValueStore _inner;
  final Clock _clock;

  /// How long a row written without an explicit ttl lives. Null means it never expires.
  final Duration? defaultTtl;

  /// The longest ttl accepted, for a store whose rows feed something with a real lease. Null means unbounded.
  final Duration? maxTtl;

  /// Writes [key] with [ttl] (or [defaultTtl]) instead of no expiry.
  Future<void> writeWithTtl(String key, Object? value, Duration ttl) {
    if (ttl.isNegative) {
      throw ArgumentError.value(ttl, 'ttl', 'cannot be negative');
    }
    final bound = maxTtl;
    final allowed = bound == null || ttl <= bound ? ttl : bound;
    return _inner.write(key, _encode(value, _clock().add(allowed)));
  }

  @override
  Future<Object?> read(String key) async {
    final stored = await _inner.read(key);
    if (stored is! String || !stored.startsWith(_envelopeMarker)) {
      return stored;
    }
    final decoded = _decodeEnvelope(stored);
    if (decoded == null) {
      return stored;
    }
    final deadline = decoded.deadline;
    if (deadline != null && !deadline.isAfter(_clock())) {
      // Expired is absent: it is removed here rather than left for a sweep, because a reader asking is the
      // cheapest moment to clean up.
      await _inner.remove(key);
      return null;
    }
    return decoded.value;
  }

  /// The remaining life of [key], or null when it is absent or never expires.
  Future<Duration?> remaining(String key) async {
    final stored = await _inner.read(key);
    if (stored is! String || !stored.startsWith(_envelopeMarker)) {
      return null;
    }
    final deadline = _decodeEnvelope(stored)?.deadline;
    if (deadline == null) {
      return null;
    }
    final left = deadline.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  Future<void> write(String key, Object? value) {
    final ttl = defaultTtl;
    if (ttl == null) {
      return _inner.write(key, value);
    }
    return writeWithTtl(key, value, ttl);
  }

  @override
  Future<void> remove(String key) => _inner.remove(key);

  @override
  Future<List<String>> keys() => _inner.keys();

  @override
  Future<void> clear() => _inner.clear();

  /// Drops every row whose deadline has passed, returning how many went. A store nobody reads still shrinks.
  Future<int> sweep() async {
    var removed = 0;
    for (final key in await _inner.keys()) {
      final stored = await _inner.read(key);
      if (stored is! String || !stored.startsWith(_envelopeMarker)) {
        continue;
      }
      final deadline = _decodeEnvelope(stored)?.deadline;
      if (deadline != null && !deadline.isAfter(_clock())) {
        await _inner.remove(key);
        removed++;
      }
    }
    return removed;
  }

  static const String _envelopeMarker = '__x__:';

  static String _encode(Object? value, DateTime deadline) =>
      '$_envelopeMarker${jsonEncode(<String, Object?>{'v': value, 'u': deadline.microsecondsSinceEpoch})}';

  static _Envelope? _decodeEnvelope(String text) {
    final body = text.substring(_envelopeMarker.length);
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) {
      return null;
    }
    final until = decoded['u'];
    return _Envelope(decoded['v'], until is int ? DateTime.fromMicrosecondsSinceEpoch(until) : null);
  }
}

final class _Envelope {
  const _Envelope(this.value, this.deadline);

  final Object? value;
  final DateTime? deadline;
}

/// A read-through LRU cache in front of a slower store.
///
/// Put this *behind* an expiring store, never in front of it, or a row outlives its own deadline in the cache.
final class CachingKeyValueStore implements KeyValueStore {
  CachingKeyValueStore({required KeyValueStore inner, this.maxEntries = kStoreDefaultMaxEntries}) : _inner = inner {
    if (maxEntries < 1) {
      throw ArgumentError.value(maxEntries, 'maxEntries', 'must hold at least one row');
    }
  }

  final KeyValueStore _inner;
  final int maxEntries;

  /// Insertion order is recency order: the front is the oldest, so eviction drops what was touched least.
  final Map<String, Object?> _cached = <String, Object?>{};

  int get size => _cached.length;

  /// Reads answered from memory since the last clear.
  int get hits => _hits;

  int _hits = 0;
  int _misses = 0;

  int get misses => _misses;

  @override
  Future<Object?> read(String key) async {
    if (_cached.containsKey(key)) {
      final value = _cached.remove(key);
      _cached[key] = value;
      _hits++;
      return value;
    }
    final value = await _inner.read(key);
    _misses++;
    _touch(key, value);
    return value;
  }

  @override
  Future<void> write(String key, Object? value) async {
    await _inner.write(key, value);
    _touch(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _inner.remove(key);
    _cached.remove(key);
  }

  @override
  Future<List<String>> keys() => _inner.keys();

  @override
  Future<void> clear() async {
    await _inner.clear();
    _cached.clear();
  }

  /// Forgets the memoised rows without touching the backend, for a host that knows the file changed.
  void invalidate() => _cached.clear();

  void _touch(String key, Object? value) {
    _cached.remove(key);
    _cached[key] = value;
    while (_cached.length > maxEntries) {
      _cached.remove(_cached.keys.first);
    }
  }
}

/// Buffers writes so a burst lands as one backend operation per window.
///
/// The settings screen writes twenty rows; the file store behind this rewrites the whole document per write,
/// which is twenty full encodes and twenty renames. A window flushes on [flushAfter], on [maxPending] rows, or
/// when [flush] is called - and a host that can be killed must call [flush] before it goes away, because
/// buffered rows are the rows a crash takes.
final class BufferedKeyValueStore implements KeyValueStore {
  BufferedKeyValueStore({
    required KeyValueStore inner,
    this.flushAfter = const Duration(milliseconds: 250),
    this.maxPending = 32,
  }) : _inner = inner {
    if (maxPending < 1) {
      throw ArgumentError.value(maxPending, 'maxPending', 'must allow at least one pending row');
    }
  }

  final KeyValueStore _inner;
  final Duration flushAfter;
  final int maxPending;

  /// null marks a deletion, so an unset key is not confused with a pending removal.
  final Map<String, Object?> _pending = <String, Object?>{};
  Timer? _timer;
  bool _closed = false;
  Future<void> _flushing = Future<void>.value();

  int get pendingCount => _pending.length;

  bool get hasPending => _pending.isNotEmpty;

  @override
  Future<Object?> read(String key) async {
    if (_pending.containsKey(key)) {
      return _pending[key];
    }
    return _inner.read(key);
  }

  @override
  Future<List<String>> keys() async {
    final stored = await _inner.keys();
    final merged = stored.toSet();
    _pending.forEach((key, value) {
      if (value == null) {
        merged.remove(key);
      } else {
        merged.add(key);
      }
    });
    return merged.toList(growable: false)..sort();
  }

  @override
  Future<void> write(String key, Object? value) async {
    _requireOpen();
    _pending[key] = value;
    _schedule();
  }

  @override
  Future<void> remove(String key) async {
    _requireOpen();
    _pending[key] = null;
    _schedule();
  }

  @override
  Future<void> clear() async {
    _requireOpen();
    for (final key in await _inner.keys()) {
      _pending[key] = null;
    }
    await flush();
  }

  /// Writes every buffered row. Concurrent calls queue behind each other instead of racing on the same rows.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    final work = _flushing.then((_) async {
      if (_pending.isEmpty) {
        return;
      }
      final batch = Map<String, Object?>.of(_pending);
      _pending.clear();
      // Awaited one by one: firing them and returning would let the caller believe a settings change was
      // saved while the file still held the old document.
      for (final entry in batch.entries) {
        final value = entry.value;
        if (value == null) {
          await _inner.remove(entry.key);
        } else {
          await _inner.write(entry.key, value);
        }
      }
    });
    _flushing = work.then<void>((_) {}, onError: (_) {});
    return work;
  }

  /// Drops the buffer and refuses further writes, flushing what was still owed.
  Future<void> close({bool discard = false}) async {
    if (discard) {
      _pending.clear();
    } else {
      await flush();
    }
    _timer?.cancel();
    _timer = null;
    _closed = true;
  }

  void _requireOpen() {
    if (_closed) {
      throw StateError('BufferedKeyValueStore is closed; a write after close would be silently dropped');
    }
  }

  void _schedule() {
    if (_pending.length >= maxPending) {
      unawaited(flush());
      return;
    }
    _timer ??= Timer(flushAfter, () {
      _timer = null;
      unawaited(flush());
    });
  }
}

/// Batch and bulk operations every store gets for free.
extension KeyValueStoreBatch on KeyValueStore {
  /// Writes rows in sequence. Sequential on purpose: a file-backed store rewrites its document per write, and
  /// firing them concurrently would have them race on the same read-modify-write.
  Future<void> writeAll(Map<String, Object?> entries) async {
    for (final entry in entries.entries) {
      await write(entry.key, entry.value);
    }
  }

  Future<void> removeAll(Iterable<String> keys) async {
    for (final key in keys) {
      await remove(key);
    }
  }

  /// The values for [keys], in the order given, absent rows as null.
  Future<List<Object?>> readAll(Iterable<String> keys) async {
    return <Object?>[for (final key in keys) await read(key)];
  }

  /// [keys] paired with their values, absent rows left out, for a caller that copies a document.
  Future<Map<String, Object?>> readAllAsMap(Iterable<String> keys) async {
    final out = <String, Object?>{};
    for (final key in keys) {
      final value = await read(key);
      if (value != null) {
        out[key] = value;
      }
    }
    return out;
  }

  /// Rows this store holds that [expected] does not name, for a migration that must report what it left
  /// behind instead of quietly keeping it.
  Future<List<String>> extraKeys(Iterable<String> expected) async {
    final wanted = expected.toSet();
    return <String>[
      for (final key in await keys())
        if (!wanted.contains(key)) key,
    ]..sort();
  }
}
