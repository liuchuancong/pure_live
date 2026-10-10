// Module: lib/src/headers.dart
// Purpose: A case-insensitive, multi-value header map that knows which of its values must never be logged.
// Author: liuchuancong
// Created: 2026-10-11
//
// Header names are case-insensitive on the wire and Dio hands them back lower-cased, so a plain Map<String,
// String> both loses repeated Set-Cookie lines and turns `Authorization` and `authorization` into two
// different headers. Redaction lives on the type rather than at each log call because the failure mode - a
// bearer token in a support attachment - is exactly what a caller forgets to think about.

/// The names whose values are credentials. Compared lower-cased.
const Set<String> kSensitiveHeaderNames = <String>{
  'authorization',
  'proxy-authorization',
  'cookie',
  'set-cookie',
  'x-api-key',
  'api-key',
  'x-auth-token',
  'authentication-info',
  'www-authenticate',
};

/// A header collection: names lower-cased, values kept in order, repeated names preserved.
final class HttpHeaderBag {
  HttpHeaderBag([Map<String, dynamic>? initial]) : _values = <String, List<String>>{} {
    if (initial != null) {
      initial.forEach(_put);
    }
  }

  final Map<String, List<String>> _values;

  /// Every name, lower-cased, in insertion order.
  List<String> get names => _values.keys.toList(growable: false);

  int get count => _values.length;

  bool get isEmpty => _values.isEmpty;

  /// The first value for [name], or null.
  String? first(String name) {
    final values = _values[_canonical(name)];
    return values == null || values.isEmpty ? null : values.first;
  }

  /// Every value for [name], in wire order. Empty when absent.
  List<String> all(String name) => List<String>.unmodifiable(_values[_canonical(name)] ?? const <String>[]);

  bool contains(String name) => _values.containsKey(_canonical(name));

  /// Replaces every value of [name] with [value].
  void set(String name, String value) => _values[_canonical(name)] = <String>[value];

  /// Appends one value, keeping what was already there (Set-Cookie, Via, Warning).
  void add(String name, String value) => _values.putIfAbsent(_canonical(name), () => <String>[]).add(value);

  void remove(String name) => _values.remove(_canonical(name));

  /// The wire form: one entry per name, repeated values joined with `, ` as HTTP spells them on the wire.
  Map<String, String> flattened() {
    return <String, String>{
      for (final entry in _values.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value.join(', '),
    };
  }

  /// The multi-value form, for handing back to a transport that takes `List<String>`.
  Map<String, List<String>> asPairs() {
    return <String, List<String>>{
      for (final entry in _values.entries) entry.key: List<String>.unmodifiable(entry.value),
    };
  }

  /// This bag with [overrides] applied on top; null-valued keys in the override remove the header.
  HttpHeaderBag mergedWith(Map<String, String?>? overrides) {
    final out = HttpHeaderBag(asPairs());
    if (overrides == null) {
      return out;
    }
    overrides.forEach((name, value) {
      if (value == null) {
        out.remove(name);
      } else {
        out.set(name, value);
      }
    });
    return out;
  }

  /// The same headers with credential values replaced, ready to hand to a logger or an error report.
  Map<String, String> redacted({Set<String> sensitive = kSensitiveHeaderNames, String marker = '[redacted]'}) {
    return <String, String>{
      for (final entry in _values.entries)
        if (entry.value.isNotEmpty) entry.key: sensitive.contains(entry.key) ? marker : entry.value.join(', '),
    };
  }

  /// Rough size in bytes, so a caller can bound what it stores about a redirect chain.
  int get byteSize {
    var total = 0;
    _values.forEach((name, values) {
      total += name.length;
      for (final value in values) {
        total += value.length + 2;
      }
    });
    return total;
  }

  void _put(String name, Object? value) {
    final key = _canonical(name);
    if (value == null) {
      return;
    }
    if (value is Iterable) {
      for (final item in value) {
        add(key, '$item');
      }
      return;
    }
    add(key, '$value');
  }

  static String _canonical(String name) => name.trim().toLowerCase();

  @override
  String toString() => 'HttpHeaderBag(${redacted()})';
}
