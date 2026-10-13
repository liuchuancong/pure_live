import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/common/normalization/site_counts.dart';

// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor

/// `"1.2万"` / `"3,400"` / bare numbers → `int?` (null = unknown).
///
/// The single persistence boundary for audience texts; adapters use
/// `parseAudienceNumberOrNull` directly when parsing responses.
final class AudienceNumberConverter implements JsonConverter<int?, Object?> {
  /// Creates a const converter instance for field annotations.
  const AudienceNumberConverter();

  @override
  int? fromJson(Object? json) => switch (json) {
    final num number => number.toInt(),
    final String text => parseAudienceNumberOrNull(text),
    _ => null,
  };

  @override
  Object? toJson(int? value) => value;
}
