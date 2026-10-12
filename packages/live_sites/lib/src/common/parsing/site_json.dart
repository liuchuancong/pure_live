import 'dart:convert';

import 'package:live_sites/src/contracts/site_error/site_error.dart';

/// JSON access shared by every adapter.
///
/// Platform payloads are untyped by nature, and the two failure modes are
/// opposite: a *missing* field should degrade (no title, no cover) while a
/// *changed* payload must fail loudly, because silently rendering an empty
/// page is how a broken site goes unnoticed for weeks. This class draws that
/// line once: `object`/`list`/`text` degrade, `decode` throws a
/// `SiteApiChangedError` with the site named.
abstract final class SiteJson {
  /// Decodes [body] as a JSON object, or throws a [SiteApiChangedError]
  /// naming [what] when it is not one.
  ///
  /// The error carries the first bytes of the body, which is what turns
  /// "the site changed" into a diagnosis: an HTML error page, a rate-limit
  /// notice and a genuinely new JSON shape each look different there.
  static Map<String, Object?> decode(String body, {required String what}) {
    final Object? root;
    try {
      root = jsonDecode(body);
    } on FormatException catch (error) {
      throw SiteApiChangedError('$what: body is not JSON (${error.message}) near "${_snippet(body)}"');
    }
    if (root is! Map<String, Object?>) {
      throw SiteApiChangedError('$what: body is not an object near "${_snippet(body)}"');
    }
    return root;
  }

  /// [value] as an object map, or an empty map when it is anything else.
  static Map<String, Object?> object(Object? value) =>
      value is Map<String, Object?> ? value : const <String, Object?>{};

  /// [value] as a list, or an empty list when it is anything else.
  static List<Object?> list(Object? value) => value is List ? value : const <Object?>[];

  /// [value] as a list of object maps, dropping entries that are not maps.
  static List<Map<String, Object?>> objects(Object? value) => [
    for (final item in list(value))
      if (item is Map<String, Object?>) item,
  ];

  /// The nested path [keys] under [root], or an empty map when any step is
  /// missing — `SiteJson.path(root, ['data', 'list'])`.
  static Object? path(Object? root, List<String> keys) {
    var current = root;
    for (final key in keys) {
      if (current is! Map<String, Object?>) {
        return null;
      }
      current = current[key];
    }
    return current;
  }

  /// The first non-null value among [values], for payloads that renamed a
  /// field (`area_name` → `areaName`).
  static Object? first(Object? Function() probe, List<Object?> values) {
    for (final value in values) {
      if (value != null) {
        return value;
      }
    }
    return probe();
  }

  static String _snippet(String body) {
    final flattened = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flattened.length > 120 ? '${flattened.substring(0, 120)}…' : flattened;
  }
}
