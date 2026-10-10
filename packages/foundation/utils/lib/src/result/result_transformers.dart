// Module: lib/src/result/result_transformers.dart
// Purpose: Combining many results without losing which ones failed.
// Author: liuchuancong
// Created: 2026-10-10
//
// Fan-out is the platform's normal shape: twelve sources answer one query. All-or-nothing combination throws
// away the nine that answered, so both modes exist and the caller picks.

import 'dart:async';

import 'result.dart';

/// Aggregates results, keeping successes and failures separated in input order.
final class ResultCollection<T, E> {
  const ResultCollection({required this.values, required this.errors});

  factory ResultCollection.from(Iterable<Result<T, E>> results) {
    final values = <T>[], errors = <E>[];
    for (final result in results) {
      switch (result) {
        case OkResult<T, E>(value: final value):
          values.add(value);
        case ErrResult<T, E>(error: final error):
          errors.add(error);
      }
    }
    return ResultCollection<T, E>(values: values, errors: errors);
  }

  /// The successes, in input order.
  final List<T> values;

  /// The failures, in input order.
  final List<E> errors;

  bool get isAllOk => errors.isEmpty;

  int get count => values.length + errors.length;
}

extension ResultIterable<T, E> on Iterable<Result<T, E>> {
  /// Splits into successes and failures, preserving order on both sides.
  ResultCollection<T, E> partition() => ResultCollection<T, E>.from(this);

  /// The list of values only when every result succeeded; the first error otherwise.
  Result<List<T>, E> collect() {
    final values = <T>[];
    for (final result in this) {
      switch (result) {
        case OkResult<T, E>(value: final value):
          values.add(value);
        case ErrResult<T, E>(error: final error):
          return ErrResult<List<T>, E>(error);
      }
    }
    return OkResult<List<T>, E>(values);
  }
}

extension ResultFutureIterable<T, E> on Iterable<Future<Result<T, E>>> {
  /// Awaits all, reporting each slot: a rejected future is still an answer about that source.
  Future<ResultCollection<T, E>> waitAll() async {
    final settled = await Future.wait(map((future) async {
      try {
        return await future;
      } catch (error) {
        return Result<T, E>.err(error is E ? error : throw error);
      }
    }));
    return ResultCollection<T, E>.from(settled);
  }
}
