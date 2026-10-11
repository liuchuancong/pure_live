// Module: lib/src/common/site_json.dart
// Purpose: The reading rules every site's response needs, shared instead of re-invented per site.
// Author: liuchuancong
// Created: 2026-10-11
//
// This is the one thing the site adapters genuinely have in common: a platform's JSON field arrives as a map,
// a number, a numeric string, a nested `{value: ...}` box or absent - sometimes all five, across versions of
// the same endpoint. Each package used to carry its own `_asMap`/`_asList`/`_intOrNull` copies, which is how
// "one odd row lost the whole page" got fixed in one site and stayed broken in another.
//
// The rule they all obey, and the reason they live here rather than in `platform`: a shape the source did not
// send is **absent**, not zero and not empty - an unknown viewer count drawn as "0" is a number the platform
// never claimed, and a page whose rows failed to parse as a page with no rows is a lie a pager trusts.

/// A response field as a map, or null when it is not one.
Map<String, Object?>? jsonMap(Object? value) => value is Map ? Map<String, Object?>.from(value) : null;

/// A response field as a list; anything that is not a list is zero rows, never an exception.
List<Object?> jsonList(Object? value) => value is List ? value : const <Object?>[];

/// A count/flag that arrives as a num, a numeric string, or a `{value: ...}` box - and null when it is
/// genuinely unstated. The map shape is not paranoia: bilibili's `view` and douyu's `giftNum` have both
/// shipped wrapped.
int? jsonInt(Object? value) => switch (value) {
  null => null,
  final num number => number.toInt(),
  final String text => int.tryParse(text.trim()),
  final Map<Object?, Object?> map => jsonInt(map['value']),
  _ => null,
};

/// The same for a duration the endpoint may state in seconds or milliseconds.
Duration? jsonDuration(Object? value, {bool milli = false}) {
  final number = jsonInt(value);
  if (number == null) {
    return null;
  }
  return milli ? Duration(milliseconds: number) : Duration(seconds: number);
}

/// A text field, with empty meaning absent - the difference a row's title fallback depends on.
String? jsonString(Object? value) {
  final text = value is String ? value.trim() : null;
  return text == null || text.isEmpty ? null : text;
}
