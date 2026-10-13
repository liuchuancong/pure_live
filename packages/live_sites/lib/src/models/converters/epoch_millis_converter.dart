import 'package:freezed_annotation/freezed_annotation.dart';

// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Milliseconds since epoch ↔ `DateTime?` (always UTC).
///
/// Accepts v1 string timestamps as input so old records keep reading; writes
/// epoch milliseconds.
final class EpochMillisConverter implements JsonConverter<DateTime?, Object?> {
  /// Creates a const converter instance for field annotations.
  const EpochMillisConverter();

  @override
  DateTime? fromJson(Object? json) => switch (json) {
    final num millis when millis > 0 => DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true),
    final String text => DateTime.tryParse(text)?.toUtc(),
    _ => null,
  };

  @override
  Object? toJson(DateTime? value) => value?.millisecondsSinceEpoch;
}
