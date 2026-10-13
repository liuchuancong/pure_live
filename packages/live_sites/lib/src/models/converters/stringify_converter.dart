import 'package:freezed_annotation/freezed_annotation.dart';

// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Platform ids that arrive as int/double → `String`.
///
/// Ids are opaque strings everywhere in this package (MODELS.md §1.2); some
/// platforms nonetheless put a number on the wire.
final class StringifyConverter implements JsonConverter<String, Object?> {
  /// Creates a const converter instance for field annotations.
  const StringifyConverter();

  @override
  String fromJson(Object? json) {
    final value = json?.toString() ?? '';
    // A double-encoded id such as `1.23058E+7` or `9999.0` is not an id.
    return value.endsWith('.0') ? value.substring(0, value.length - 2) : value;
  }

  @override
  Object? toJson(String value) => value;
}
