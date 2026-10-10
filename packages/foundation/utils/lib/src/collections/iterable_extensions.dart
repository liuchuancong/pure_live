// Module: lib/src/collections/iterable_extensions.dart
// Purpose: Reading an Iterable the way the platform actually does it, without allocating intermediates.
// Author: liuchuancong
// Created: 2026-10-10

extension IterableUtils<T> on Iterable<T> {
  /// The first element, or null when empty.
  ///
  /// package:collection has this as an extension member, so it cannot be referenced as a function; the
  /// one-line body here keeps the repo's own definition reachable from the barrel.
  T? get head {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }

  /// The only element, or null when there are none or several.
  ///
  /// There should be exactly one is a question about data quality, and the answer for zero and for many is
  /// usually the same: treat it as absent and let the caller record the surprise.
  T? get singleOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    final only = iterator.current;
    return iterator.moveNext() ? null : only;
  }

  /// Elements whose [keyOf] has not appeared before, preserving order.
  Iterable<T> uniqueBy<K>(K Function(T item) keyOf) sync* {
    final seen = <K>{};
    for (final item in this) {
      if (seen.add(keyOf(item))) {
        yield item;
      }
    }
  }

  /// The sum of [selector], avoiding the map-then-fold pair every totals screen writes.
  int sumBy(int Function(T item) selector) {
    var total = 0;
    for (final item in this) {
      total += selector(item);
    }
    return total;
  }

  /// Splits into a kept half and a dropped half by one predicate, in one pass.
  ({List<T> kept, List<T> dropped}) partitionBy(bool Function(T item) keep) {
    final kept = <T>[], dropped = <T>[];
    for (final item in this) {
      (keep(item) ? kept : dropped).add(item);
    }
    return (kept: kept, dropped: dropped);
  }
}
