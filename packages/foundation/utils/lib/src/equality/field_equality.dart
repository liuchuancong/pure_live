// Module: lib/src/equality/field_equality.dart
// Purpose: One definition of "same fields, same value" for the hand-written value types in this repository.
// Author: liuchuancong
// Created: 2026-10-10
//
// Measured duplication: twelve value types in the platform contract package alone each write their own
// `operator ==` and `hashCode`, and the bugs in that pattern are silent - a missing field makes two
// different content references compare equal, and an `Object.hash` on a field list that contains a list
// hashes by identity, so an equal pair disagrees about it. Dart does not give a plain class structural
// equality, and `package:equatable` would put a pub.dev dependency in front of every model in the repo.
//
// The tag is the concrete [runtimeType], not a name string: `Ok(1)` and `Err(1)` must never be equal, and a
// subclass that forgets to declare its fields fails at the assert instead of quietly matching a sibling.

/// Structural equality over [equalityFields].
///
/// Mixed into an immutable value type. Every field that participates in identity has to appear in the list,
/// in the same order as [hashCode] needs them - which is the point: one list, two operations, no way for
/// them to drift apart.
mixin ValueEquality {
  /// The fields that define this value.
  List<Object?> get equalityFields;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    final candidate = other as ValueEquality;
    return sameFieldList(equalityFields, candidate.equalityFields);
  }

  @override
  int get hashCode => Object.hash(runtimeType, deepHashAll(equalityFields));
}

/// True when two field lists hold equal values, comparing nested collections by content.
///
/// A plain `==` on a `List` field compares identity, which is the bug this exists to kill: a descriptor
/// holding a list of protocols looked unequal to a byte-identical twin.
bool sameFieldList(List<Object?> left, List<Object?> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (!deepEquals(left[index], right[index])) {
      return false;
    }
  }
  return true;
}

/// Equality that recurses through [List], [Set] and [Map] by content.
///
/// Order matters for a list and not for a set, matching how the sdk collections already compare; a value
/// type holding an unordered set has to say so by storing a [Set].
///
/// Cycles are not supported: a field that points back at its own owner is not an immutable value, and
/// getting here would be the caller's bug, not something to mask with an identity cache.
bool deepEquals(Object? left, Object? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left is List && right is List) {
    return sameFieldList(left, right);
  }
  if (left is Set && right is Set) {
    if (left.length != right.length) {
      return false;
    }
    for (final value in left) {
      if (!right.any((other) => deepEquals(value, other))) {
        return false;
      }
    }
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key)) {
        return false;
      }
      if (!deepEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

/// A hash consistent with [deepEquals] for a list of values.
int deepHashAll(Iterable<Object?> values) {
  var hash = 17;
  for (final value in values) {
    hash = Object.hash(hash, deepHash(value));
  }
  return hash;
}

/// A hash consistent with [deepEquals] for one value.
int deepHash(Object? value) {
  if (value is List) {
    return Object.hash('list', deepHashAll(value));
  }
  // A set's order is not part of its content, so the parts are combined in an order-independent way.
  if (value is Set) {
    return Object.hashAllUnordered(value.map(deepHash));
  }
  if (value is Map) {
    return Object.hash(
      'map',
      Object.hashAllUnordered(value.entries.map((entry) => Object.hash(deepHash(entry.key), deepHash(entry.value)))),
    );
  }
  return value.hashCode;
}
