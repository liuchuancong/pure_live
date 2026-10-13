import 'package:freezed_annotation/freezed_annotation.dart';

// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor

/// ISO-8601 text ↔ `DateTime?` (always UTC).
///
/// Naive input (no offset) is interpreted as already-UTC, matching how
/// platforms send programme times without zone markers.
final class IsoTimeConverter implements JsonConverter<DateTime?, Object?> {
  /// Creates a const converter instance for field annotations.
  const IsoTimeConverter();

  @override
  DateTime? fromJson(Object? json) => switch (json) {
    final String text when text.isNotEmpty => DateTime.tryParse(text)?.toUtc(),
    _ => null,
  };

  @override
  Object? toJson(DateTime? value) => value?.toIso8601String();
}
