// Module: lib/src/preferences/preference_key.dart
// Purpose: The vocabulary-free preference contract - a named, typed key with its own default and codec.
// Author: liuchuancong
// Created: 2026-10-10
//
// Spec: docs/architecture/application-portfolio.md section 5 forbids one product's vocabulary leaking into
// shared code, and section 3 makes this the layer every app may reach. So a key is a value the *consumer*
// declares: storage owns how a preference is stored, validated and announced, never which preferences exist.
// That is also why the default lives on the key instead of in a registry the store would have to know.
//
// Why it lives here rather than in its own package: the mechanism reads and writes a KeyValueStore, which is
// this package's own type, and section 3 forbids one foundation package depending on another. It also sits
// beside SchemaMigrator for a second reason - a preference row that predates the envelope is migrated by a
// schema step, and the two halves of that story belong in one place.

/// How a stored value is decoded, and what "no answer" means for one key.
///
/// The closed set exists because a wrong-type read must not be stringified into a plausible value: `'${5}'`
/// turns a stored number into the string `'5'`, and the next write then keeps the wrong type forever.
final class PreferenceCodec<T extends Object> {
  const PreferenceCodec._(this.name, this._parse, this._encode);

  /// The codec's own name, recorded in the stored envelope so a reader can tell what it was written as.
  final String name;

  final T? Function(Object? raw) _parse;
  final Object? Function(T value) _encode;

  /// Returns null when [raw] is not a valid [T]; the caller then falls back to the key's default.
  T? decode(Object? raw) => _parse(raw);

  /// The JSON-safe form written into the key-value store.
  Object? encode(T value) => _encode(value);

  /// Named `boolean`, not `bool`: a static member called `bool` would shadow the built-in type inside this
  /// class body, and the declaration of itself could no longer name its own type argument.
  static const PreferenceCodec<bool> boolean = PreferenceCodec<bool>._('bool', _parseBool, _passThrough);

  static const PreferenceCodec<int> integer = PreferenceCodec<int>._('int', _parseInt, _passThrough);

  static const PreferenceCodec<double> real = PreferenceCodec<double>._('double', _parseDouble, _passThrough);

  static const PreferenceCodec<String> string = PreferenceCodec<String>._('string', _parseString, _passThrough);

  /// A list of strings, e.g. an ordering of ids the app defines elsewhere.
  ///
  /// It is stored as a real JSON list rather than a joined string: a separator-based encoding breaks the
  /// round trip as soon as one id contains the separator, and no escaping scheme is worth its own bug class.
  static const PreferenceCodec<List<String>> stringList = PreferenceCodec<List<String>>._(
    'stringList',
    _parseStringList,
    _copyStringList,
  );

  /// A caller-owned type, decoded through the consumer's own parse and serialize.
  ///
  /// [name] must be stable and unique per shape: it is written into the envelope, so renaming it is a
  /// migration, not a refactor.
  static PreferenceCodec<T> of<T extends Object>(
    String name,
    T? Function(Object? raw) parse,
    Object? Function(T value) serialize,
  ) => PreferenceCodec<T>._(name, parse, serialize);
}

/// Thrown by a codec's parse to refuse a value while saying why.
///
/// Returning null already means "not usable"; the difference is that a consumer's own report loses the reason.
/// A row from a newer build and a row missing its order list are both unreadable, but only one of them is
/// fixed by upgrading the app - and the user-facing sentence has to know which.
final class PreferenceDecodeReject implements Exception {
  const PreferenceDecodeReject(this.reason);

  /// Why this value was refused. Written for a diagnostics view, so it names fields rather than echoing bytes.
  final String reason;

  @override
  String toString() => 'PreferenceDecodeReject($reason)';
}

/// The type-independent part of a preference key.
///
/// Dart generics are invariant, so a `PreferenceKey<String>` is not a `PreferenceKey<Object>`: an API that
/// takes a list of keys would refuse a caller's mixed-type table. Anything that only needs the name and the
/// stored shape takes this instead - which is exactly what import and existence checks need.
abstract interface class PreferenceKeyInfo {
  String get name;

  /// The codec name written into the envelope; a mismatch means the value was written under another type.
  String get codecName;
}

/// One preference: its storage name, its type, and the answer to give when nothing valid is stored.
final class PreferenceKey<T extends Object> implements PreferenceKeyInfo {
  const PreferenceKey({
    required this.name,
    required this.codec,
    required this.defaultValue,
    this.validate,
    this.upgrade,
  });

  /// The key inside the store's namespace. Stable forever: renaming it orphans existing user data.
  @override
  final String name;

  final PreferenceCodec<T> codec;

  @override
  String get codecName => codec.name;

  /// Used for an absent key and for a stored value that no longer decodes. A preference read must never be
  /// the reason a screen cannot render, but the fallback is reported through the store's rejection notice.
  final T defaultValue;

  /// An optional range rule for the consumer's own type - a quality label set, a page size ceiling.
  ///
  /// It lives here rather than at each call site so a value read back from disk is checked by the same rule
  /// that guarded the write; otherwise an import could smuggle past the caller.
  final bool Function(T value)? validate;

  /// Reads a value written before this store's envelope existed, and returns what the codec should make of it.
  ///
  /// Without this hook, adopting the store silently deletes a user's setting: a legacy row is not an envelope,
  /// an unreadable read falls back to the key's default, and the next write persists that default as if the
  /// user had chosen it. Returning null keeps the value "unknown shape", which is the honest answer for a
  /// document this consumer never wrote. Return the raw inner value (what `value` would hold), not an envelope.
  ///
  /// A read never rewrites the row, so this runs on every read until an explicit migration replaces the row -
  /// which is what `pure_live_storage`'s SchemaMigrator step is for.
  final Object? Function(Object? raw)? upgrade;

  @override
  bool operator ==(Object other) => other is PreferenceKey<T> && other.name == name && other.codec.name == codec.name;

  @override
  int get hashCode => Object.hash(name, codec.name);

  @override
  String toString() => 'PreferenceKey($name ${codec.name})';
}

/// Why one stored value was not used as-is.
enum PreferenceFailure {
  /// The envelope is missing its version, so the value's shape is unknown.
  unreadableEnvelope,

  /// The codec recognised the envelope and refused the value inside it, saying why in [PreferenceRejection.reason].
  refusedByCodec,

  /// The envelope names a codec this key does not use - a writer changed the type under the same name.
  codecMismatch,

  /// The codec accepted the shape but the value is out of range for the key's own rule.
  invalidValue,
}

/// One rejected stored value, kept so a caller can report it instead of silently disagreeing with the disk.
final class PreferenceRejection {
  const PreferenceRejection({required this.keyName, required this.failure, this.rawType, this.reason});

  final String keyName;
  final PreferenceFailure failure;

  /// The runtime type of what was on disk, never the value itself: a preference may hold a path or a label a
  /// diagnostic report should not echo.
  final String? rawType;

  /// The codec's own words, carried from [PreferenceDecodeReject] when it threw.
  ///
  /// It exists because "unreadable" is not one fact but several, and a consumer that used to be able to tell
  /// "a newer build wrote this" from "the row has no order list" loses that difference if the reason is
  /// collapsed into an enum. Nothing here is optional about the *enum*: [failure] still classifies the outcome
  /// for code that only needs to count them.
  final String? reason;

  @override
  String toString() {
    final detail = reason ?? (rawType == null ? '' : 'was $rawType');
    return 'PreferenceRejection($keyName ${failure.name}${detail.isEmpty ? '' : ': $detail'})';
  }
}

/// A value that changed, as announced to whoever is watching the settings screen.
///
/// It carries the key name rather than the typed key: one stream has to serve every type, and a listener
/// that cares about the type already holds the key it subscribed for.
final class PreferenceChange {
  const PreferenceChange({required this.keyName, required this.value, required this.wasDefault});

  final String keyName;
  final Object value;

  /// True when the write removed the stored value and the key is back on its default.
  final bool wasDefault;

  @override
  String toString() => 'PreferenceChange($keyName = $value${wasDefault ? ' (default)' : ''})';
}

// ------------------------------------------------------------------ codec bodies --
//
// Top-level functions rather than inline closures: a const PreferenceCodec needs constant arguments, and a
// function reference is constant while a lambda is not.

Object? _passThrough(Object? value) => value;

bool? _parseBool(Object? raw) => raw is bool ? raw : null;

int? _parseInt(Object? raw) => raw is int ? raw : null;

/// An int stored by an older writer is still a real number; the reverse would lose precision, so it stays
/// refused.
double? _parseDouble(Object? raw) => raw is double ? raw : (raw is int ? raw.toDouble() : null);

String? _parseString(Object? raw) => raw is String ? raw : null;

List<String>? _parseStringList(Object? raw) {
  if (raw is! List) {
    return null;
  }
  final values = <String>[];
  for (final item in raw) {
    if (item is! String) {
      return null;
    }
    values.add(item);
  }
  return List<String>.unmodifiable(values);
}

Object? _copyStringList(List<String> value) => List<String>.unmodifiable(value);
