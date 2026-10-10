// Module: lib/src/result/result_transformers.dart
// Purpose: The seam between code that throws and code that returns a Result, plus chaining across a future.
// Author: liuchuancong
// Created: 2026-10-08
//
// docs/DEVELOPMENT_STANDARDS.md section 3.4 forbids both using exceptions for normal flow and swallowing
// them, so the boundary has to be explicit and in one place: a throwing io call becomes an `err` at the
// edge that owns the domain error type, and nothing in between needs a try/catch.

import 'dart:async';

import 'result.dart';

/// Runs [operation], turning a throw into a failure of type [E].
///
/// [onFailure] is required rather than defaulted to `Object`: choosing the error type is the caller's job,
/// and a default would put raw exceptions into domain results.
Result<T, E> captureResult<T, E>(T Function() operation, {required E Function(Object error) onFailure}) {
  try {
    return OkResult<T, E>(operation());
  } catch (error) {
    return ErrResult<T, E>(onFailure(error));
  }
}

/// The async form of [captureResult].
Future<Result<T, E>> captureAsync<T, E>(
  Future<T> Function() operation, {
  required E Function(Object error) onFailure,
}) async {
  try {
    return OkResult<T, E>(await operation());
  } catch (error) {
    return ErrResult<T, E>(onFailure(error));
  }
}

extension ResultFutureUtils<T, E> on Future<Result<T, E>> {
  /// Chains an operation that can itself fail once this one succeeds.
  Future<Result<R, E>> andThen<R>(Future<Result<R, E>> Function(T value) next) async {
    final result = await this;
    return switch (result) {
      OkResult<T, E>(value: final value) => await next(value),
      ErrResult<T, E>(error: final error) => ErrResult<R, E>(error),
    };
  }

  /// Replaces a failure with another result, which is where a fallback source belongs.
  Future<Result<T, F>> recover<F>(Future<Result<T, F>> Function(E error) fallback) async {
    final result = await this;
    return switch (result) {
      OkResult<T, E>(value: final value) => OkResult<T, F>(value),
      ErrResult<T, E>(error: final error) => await fallback(error),
    };
  }
}
