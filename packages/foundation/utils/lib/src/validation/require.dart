// Module: lib/src/validation/require.dart
// Purpose: Reject an unusable argument at a public boundary, with the parameter named in the failure.
// Author: liuchuancong
// Created: 2026-10-10
//
// Measured duplication: eighty-two hand-written `ArgumentError(...)` / `StateError(...)` sites across the
// repository, most of them re-deriving the same three rules and each choosing a different message shape.
// A preference key that accepts a blank name, a page size that accepts zero, a codec that accepts an empty
// list - all of them fail later, somewhere the cause is no longer visible.
//
// These check *arguments*, not results: an out-of-range value here means the caller is wrong, so
// [ArgumentError] is the right type and a Result would be a lie. A foreseeable failure belongs to the
// domain, and the domain type is what the caller declares.

/// A non-blank string, trimmed.
///
/// Blank means empty or whitespace only, because an id made of spaces round-trips through every store and
/// comes out looking like a real, unmatched key.
String requireNonBlank(String? value, {required String name}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'must be a non-blank string');
  }
  return trimmed;
}

/// [value] when it lies inside the closed range [lower]..[upper].
int requireInRange(int value, {required int lower, required int upper, required String name}) {
  if (lower > upper) {
    throw ArgumentError.value(upper, 'upper', 'must not be below lower ($lower)');
  }
  if (value < lower || value > upper) {
    throw ArgumentError.value(value, name, 'must be within $lower..$upper');
  }
  return value;
}

/// A non-empty list.
///
/// [allowNull] is not an option here: an absent collection and an empty one answer different questions, and
/// a caller that accepts both should say so at its own boundary instead of through this one.
List<T> requireNotEmpty<T>(List<T> values, {required String name}) {
  if (values.isEmpty) {
    throw ArgumentError.value(values, name, 'must contain at least one element');
  }
  return values;
}

/// The value of [value], refusing null.
///
/// This is the guard for a field that a caller proved exists one line earlier; where the absence is
/// foreseeable, a nullable return or a Result is the honest shape and this function is the wrong tool.
T requireNonNull<T>(T? value, {required String name}) {
  if (value == null) {
    throw ArgumentError.value(value, name, 'must not be null');
  }
  return value;
}
