// Module: lib/src/support/json.dart
// Purpose: Shared JSON coercion helpers that keep every platform model tolerant of unknown fields and UTC-normalized in time.
// Author: liuchuancong
// Created: 2026-10-08
//
// Rules implemented here come from docs/contracts/platform-models.md section 16: enums travel as their
// name, unknown fields must not break an older reader, persisted timestamps are UTC and durations are
// milliseconds rather than bare floating point seconds.

/// Returns a string-keyed copy of [value], or an empty map when it is absent or not a map.
///
/// A JSON decoder may hand back `Map<Object?, Object?>`, so the copy is also the place where keys are
/// normalized once instead of at every use site.
Map<String, Object?> asObjectMap(Object? value) {
  if (value is! Map) {
    return const <String, Object?>{};
  }
  return Map<String, Object?>.fromEntries(
    value.entries.map((entry) => MapEntry('${entry.key}', entry.value)),
  );
}

/// Returns the entries of [value] that are themselves JSON objects.
List<Map<String, Object?>> asObjectMapList(Object? value) {
  if (value is! List) {
    return const <Map<String, Object?>>[];
  }
  return value.whereType<Map<Object?, Object?>>().map(asObjectMap).toList(growable: false);
}

/// Parses an ISO-8601 timestamp and normalizes it to UTC, as required for persisted values.
DateTime? parseUtc(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

/// Formats [value] as UTC so two writers never disagree about the stored offset.
String? formatUtc(DateTime? value) => value?.toUtc().toIso8601String();

/// Reads a duration stored in milliseconds; a bare seconds float is a bug, not a format.
Duration? parseDurationMs(Object? value) {
  if (value is int) {
    return Duration(milliseconds: value);
  }
  if (value is num) {
    return Duration(milliseconds: value.round());
  }
  return null;
}

/// Encodes a duration as milliseconds, the unit every model in this package persists with.
int? durationMs(Duration? value) => value?.inMilliseconds;

/// Finds an enum value by its name, returning null when the writer used a value this reader predates.
T? enumByName<T extends Enum>(List<T> values, String? name) {
  if (name == null) {
    return null;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}

/// Reads a required string field, naming the model and field when it is missing.
///
/// A bare `json['id']!` throws a null check error with no context, which makes a corrupt stored record
/// impossible to trace back to the writer that produced it.
String requireString(Map<String, Object?> json, String field, String model) {
  final value = json[field];
  if (value is! String || value.isEmpty) {
    throw FormatException('$model is missing required field "$field" (got ${json[field]})');
  }
  return value;
}
