// Module: lib/src/collections.dart
// Purpose: Small collection helpers that the platform needs and the SDK does not provide.
// Author: liuchuancong
// Created: 2026-10-08
//
// Deliberately narrow: anything a single feature needs belongs in that feature, not here.

/// Groups items preserving first-seen key order, which a plain map does not guarantee across platforms.
Map<K, List<T>> groupBy<T, K>(Iterable<T> items, K Function(T item) keyOf) {
  final grouped = <K, List<T>>{};
  for (final item in items) {
    grouped.putIfAbsent(keyOf(item), () => <T>[]).add(item);
  }
  return grouped;
}

/// Maps and drops nulls in one pass, keeping the result non-null typed.
List<R> mapNotNull<T, R>(Iterable<T> items, R? Function(T item) transform) {
  final mapped = <R>[];
  for (final item in items) {
    final value = transform(item);
    if (value != null) {
      mapped.add(value);
    }
  }
  return mapped;
}

/// Keeps the first element for each computed key, preserving input order.
List<T> distinctBy<T, K>(Iterable<T> items, K Function(T item) keyOf) {
  final seen = <K>{};
  final distinct = <T>[];
  for (final item in items) {
    if (seen.add(keyOf(item))) {
      distinct.add(item);
    }
  }
  return distinct;
}

/// Splits into consecutive chunks of at most [size]; [size] must be positive.
List<List<T>> chunked<T>(Iterable<T> items, int size) {
  if (size < 1) {
    throw ArgumentError.value(size, 'size', 'must be at least 1');
  }
  final chunks = <List<T>>[];
  final buffer = <T>[];
  for (final item in items) {
    buffer.add(item);
    if (buffer.length == size) {
      chunks.add(List<T>.of(buffer));
      buffer.clear();
    }
  }
  if (buffer.isNotEmpty) {
    chunks.add(List<T>.of(buffer));
  }
  return chunks;
}
