import 'package:freezed_annotation/freezed_annotation.dart';

// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor

/// URL text ↔ `Uri?`.
///
/// Malformed input yields null instead of throwing: a broken link must not
/// take a whole stored record down with it.
final class UriStringConverter implements JsonConverter<Uri?, Object?> {
  /// Creates a const converter instance for field annotations.
  const UriStringConverter();

  @override
  Uri? fromJson(Object? json) => switch (json) {
    final String text when text.trim().isNotEmpty => Uri.tryParse(text.trim()),
    _ => null,
  };

  @override
  Object? toJson(Uri? value) => value?.toString();
}
