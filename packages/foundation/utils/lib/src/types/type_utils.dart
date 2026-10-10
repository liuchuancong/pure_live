// Module: lib/src/types/type_utils.dart
// Purpose: A usable void, and one way to ask whether an unknown value has the type you expected.
// Author: liuchuancong
// Created: 2026-10-10
//
// Two gaps the sdk leaves. `void` cannot be a generic argument you construct, so `Result<void, E>` is not a
// thing and every write-only operation had to pick a dummy type. And the values that come out of a kv store,
// a decoded json body or a script return are `Object?`, so the repository's decoders are one
// `raw is X ? raw : null` test after another - the preference codecs alone write that test six times.
//
// There is deliberately one spelling of the cast question, not three: `as` is a reserved word so the method
// form is named for what it returns, and a null answer means "unrecognised shape", never "wrong program".

/// The value for an operation that succeeds without producing anything.
///
/// Use it as the success type of a `Result<Unit, E>` for writes, deletes and dispatches.
final class Unit {
  const Unit();

  /// The single instance, so a caller does not allocate one per result.
  static const Unit value = Unit();

  @override
  bool operator ==(Object other) => other is Unit;

  @override
  int get hashCode => 'Unit'.hashCode;

  @override
  String toString() => 'Unit';
}

extension TypeChecks on Object? {
  /// The receiver as a [T], or null when it is not one.
  ///
  /// Prefer this over `raw as T?` when the mismatch is a foreseeable shape rather than a programming error:
  /// a stored preference of the wrong type is data, and a cast raises where the caller already has a default
  /// path.
  T? asOrNull<T>() => this is T ? this as T : null;

  /// [fallback] when this is not a [T].
  ///
  /// The named form of the same rule, for the common one-line default.
  T or<T>(T fallback) => this is T ? this as T : fallback;
}
