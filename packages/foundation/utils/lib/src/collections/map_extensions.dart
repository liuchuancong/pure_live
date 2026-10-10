// Module: lib/src/collections/map_extensions.dart
// Purpose: Map operations that keep insertion order meaningful.
// Author: liuchuancong
// Created: 2026-10-10

extension MapUtils<K, V> on Map<K, V> {
  /// The value for [key], inserting and returning [create] when absent.
  V getOrPut(K key, V Function() create) => putIfAbsent(key, create);

  /// A map with [entries] merged in, leaving the receiver untouched.
  ///
  /// Used by settings and manifest merging, where the defaults plus what the user chose must not mutate the
  /// defaults object other callers still hold.
  Map<K, V> mergedWith(Map<K, V> entries) => <K, V>{...this, ...entries};

  /// Entries whose value passes [test], preserving order.
  Map<K, V> whereValue(bool Function(K key, V value) test) {
    final kept = <K, V>{};
    for (final entry in entries) {
      if (test(entry.key, entry.value)) {
        kept[entry.key] = entry.value;
      }
    }
    return kept;
  }

  /// The value only when it is present and passes [validate]; otherwise null, without throwing.
  ///
  /// External maps - a manifest, a parsed response - answer questions about shape far more often than about
  /// absence, and a null result keeps both cases out of the exception path.
  V? readWhere(Object key, bool Function(V value) validate) {
    final value = this[key];
    return value == null || !validate(value) ? null : value;
  }
}
