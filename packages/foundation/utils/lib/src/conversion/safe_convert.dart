// Module: lib/src/conversion/safe_convert.dart
// Purpose: Convert values whose shape is only known at runtime - decoded json, kv reads, script returns -
// into a type or null, never a throw.
// Author: liuchuancong
// Created: 2026-10-10
//
// Measured duplication: parsers in the providers, the storage layer and the preferences codecs each write
// their own `int.tryParse('$raw')` or `raw is num ? ... : null` dance, and a json field that arrives as
// `"2100"` instead of `2100` breaks whichever one of them forgot to allow both. These are the only rules
// the repository uses; a converter that guesses (empty string to zero, "false" to a bool) would turn a
// source's typo into a plausible value, which is worse than a null.
//
// Null means "this was not that kind of value". Callers decide the default; nothing here invents one.

/// [value] as an int, accepting a numeric string and an integral double.
int? intFrom(Object? value) => switch (value) {
  final int value => value,
  final double value when value == value.roundToDouble() && !value.isNaN && !value.isInfinite => value.toInt(),
  final String text => int.tryParse(text.trim()),
  _ => null,
};

/// [value] as a double, accepting an int and a numeric string.
double? doubleFrom(Object? value) => switch (value) {
  final double value => value.isNaN ? null : value,
  final int value => value.toDouble(),
  final String text => double.tryParse(text.trim()),
  _ => null,
};

/// [value] as a bool.
///
/// A number is a bool only as 0 or 1: sources do send `{"enabled": 1}`, and accepting any non-zero value
/// would make a count look like a flag.
bool? boolFrom(Object? value) => switch (value) {
  final bool value => value,
  1 => true,
  0 => false,
  final String text => switch (text.trim().toLowerCase()) {
    'true' || '1' || 'yes' => true,
    'false' || '0' || 'no' => false,
    _ => null,
  },
  _ => null,
};

/// [value] rendered as text, or '' when it is null.
///
/// The empty default is deliberate: callers used to write `'${raw ?? ''}'` for display strings, and the
/// difference between a missing label and a blank one has never mattered in this UI. Use [stringOrNull]
/// when it does.
String stringFrom(Object? value) => value == null ? '' : '$value';

/// [value] as text, or null when it is absent - the form a required field needs.
String? stringOrNull(Object? value) => switch (value) {
  final String text => text.isEmpty ? null : text,
  null => null,
  _ => '$value',
};

/// [value] as a json object with string keys.
Map<String, dynamic>? jsonMapFrom(Object? value) {
  if (value is! Map) {
    return null;
  }
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    // A non-string key means this is not a decoded json object any more, so the whole value is refused
    // rather than half-converted.
    if (entry.key is! String) {
      return null;
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

/// [value] as a list, or null when it is not one.
List<Object?>? listFrom(Object? value) => value is List ? List<Object?>.unmodifiable(value) : null;

/// [value] as a list of strings, skipping entries that are not strings.
List<String>? stringListFrom(Object? value) {
  if (value is! List) {
    return null;
  }
  final items = <String>[];
  for (final item in value) {
    if (item is! String) {
      return null;
    }
    items.add(item);
  }
  return List<String>.unmodifiable(items);
}
