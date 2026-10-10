// Module: lib/src/result/result_extensions.dart
// Purpose: The reading and branching callers do on a Result, without a switch at every call site.
// Author: liuchuancong
// Created: 2026-10-10

import 'result.dart';

/// Thrown by [ResultUtils.requireValue] when a result was a failure.
final class ResultFailureException<E> implements Exception {
  const ResultFailureException(this.error);

  final E error;

  @override
  String toString() => 'ResultFailureException: $error';
}

extension ResultUtils<T, E> on Result<T, E> {
  /// The success value, or throws [ResultFailureException].
  ///
  /// Only for paths where a failure is genuinely not expected - a test assertion, or a call that already
  /// checked. Everywhere else the caller has to say what happens on failure, which is the point of the type.
  T requireValue() => switch (this) {
    OkResult<T, E>(value: final value) => value,
    ErrResult<T, E>(error: final error) => throw ResultFailureException<E>(error),
  };

  /// Collapses both cases into one value, which is what a widget usually wants to render.
  R fold<R>({required R Function(T value) onOk, required R Function(E error) onErr}) => switch (this) {
    OkResult<T, E>(value: final value) => onOk(value),
    ErrResult<T, E>(error: final error) => onErr(error),
  };

  /// Runs [action] with the error and returns this result, for logging a failure without a branch.
  Result<T, E> tapErr(void Function(E error) action) => onErr(action);
}
