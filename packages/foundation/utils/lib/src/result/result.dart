// Module: lib/src/result/result.dart
// Purpose: A value-or-failure result type so callers handle expected failures without exceptions in control flow.
// Author: liuchuancong
// Created: 2026-10-08
//
// docs/DEVELOPMENT_STANDARDS.md section 3.4 forbids using exceptions for normal flow and forbids swallowing
// them. Result covers the expected-failure half: a resolver that found nothing, a parser that rejected an
// entry. Exceptions stay reserved for genuinely exceptional conditions.

/// The outcome of an operation that can fail in a foreseeable way.
sealed class Result<T, E> {
  const Result();

  /// A successful outcome carrying [value].
  const factory Result.ok(T value) = OkResult<T, E>;

  /// A failed outcome carrying the domain error [error].
  const factory Result.err(E error) = ErrResult<T, E>;

  bool get isOk;

  bool get isErr => !isOk;

  /// The success value, or null for a failure.
  T? get valueOrNull;

  /// The error, or null for a success.
  E? get errorOrNull;

  /// Returns the value or [fallback].
  T unwrapOr(T fallback) => valueOrNull ?? fallback;

  /// Returns the value or computes a fallback from the error.
  T unwrapOrElse(T Function(E error) fallback);

  /// Transforms the success value, passing a failure through untouched.
  Result<R, E> map<R>(R Function(T value) transform);

  /// Replaces the error type, passing a success through untouched.
  Result<T, F> mapError<F>(F Function(E error) transform);

  /// Chains an operation that can itself fail.
  Result<R, E> flatMap<R>(Result<R, E> Function(T value) next);

  /// Runs [action] only on success; useful for emitting a diagnostic without branching.
  Result<T, E> onOk(void Function(T value) action);

  /// Runs [action] only on failure.
  Result<T, E> onErr(void Function(E error) action);
}

/// A success carrying [value].
final class OkResult<T, E> extends Result<T, E> {
  const OkResult(this.value) : super();

  final T value;

  @override
  bool get isOk => true;

  @override
  T? get valueOrNull => value;

  @override
  E? get errorOrNull => null;

  @override
  T unwrapOrElse(T Function(E error) fallback) => value;

  @override
  Result<R, E> map<R>(R Function(T value) transform) => OkResult<R, E>(transform(value));

  @override
  Result<T, F> mapError<F>(F Function(E error) transform) => OkResult<T, F>(value);

  @override
  Result<R, E> flatMap<R>(Result<R, E> Function(T value) next) => next(value);

  @override
  Result<T, E> onOk(void Function(T value) action) {
    action(value);
    return this;
  }

  @override
  Result<T, E> onErr(void Function(E error) action) => this;

  @override
  bool operator ==(Object other) => other is OkResult<T, E> && other.value == value;

  @override
  int get hashCode => Object.hash('ok', value);

  @override
  String toString() => 'Ok($value)';
}

/// A failure carrying [error].
final class ErrResult<T, E> extends Result<T, E> {
  const ErrResult(this.error) : super();

  final E error;

  @override
  bool get isOk => false;

  @override
  T? get valueOrNull => null;

  @override
  E? get errorOrNull => error;

  @override
  T unwrapOrElse(T Function(E error) fallback) => fallback(error);

  @override
  Result<R, E> map<R>(R Function(T value) transform) => ErrResult<R, E>(error);

  @override
  Result<T, F> mapError<F>(F Function(E error) transform) => ErrResult<T, F>(transform(error));

  @override
  Result<R, E> flatMap<R>(Result<R, E> Function(T value) next) => ErrResult<R, E>(error);

  @override
  Result<T, E> onOk(void Function(T value) action) => this;

  @override
  Result<T, E> onErr(void Function(E error) action) {
    action(error);
    return this;
  }

  @override
  bool operator ==(Object other) => other is ErrResult<T, E> && other.error == error;

  @override
  int get hashCode => Object.hash('err', error);

  @override
  String toString() => 'Err($error)';
}
