// Module: lib/src/collections/list_extensions.dart
// Purpose: Positional operations on a List, where index arithmetic is the whole point.
// Author: liuchuancong
// Created: 2026-10-10

extension ListUtils<T> on List<T> {
  /// The element at [index], or null when the index is out of range.
  ///
  /// Paging and queue code ask whether there is something at this position constantly; throwing on the
  /// negative answer means every caller writes the same bounds check.
  T? elementAtOrNull(int index) {
    if (index < 0 || index >= length) {
      return null;
    }
    return this[index];
  }

  /// Moves the element at [from] to [to], shifting the rest. Out-of-range indices throw.
  T move(int from, int to) {
    RangeError.checkValidIndex(from, this, 'from', length);
    RangeError.checkValidIndex(to, this, 'to', length);
    if (from == to) {
      return this[from];
    }
    final moved = removeAt(from);
    insert(to, moved);
    return moved;
  }

  /// A copy with [value] appended, capped at [maxSize] by dropping from the front.
  ///
  /// Bounded lists show up wherever a user-visible history lives; writing the trim at each call site is how
  /// one of them forgets and grows forever.
  List<T> appended(T value, {required int maxSize}) {
    if (maxSize < 1) {
      throw ArgumentError.value(maxSize, 'maxSize', 'must be at least 1');
    }
    final next = <T>[...this, value];
    final overflow = next.length - maxSize;
    return overflow > 0 ? next.sublist(overflow) : next;
  }

  /// The index of the first element matching [test], or null.
  ///
  /// `indexWhere` already does this with an int; this returns null instead of -1 so the caller cannot
  /// mistake the sentinel for a position.
  int? indexOfOrNull(bool Function(T item) test) {
    final found = indexWhere(test);
    return found < 0 ? null : found;
  }
}
