// Module: lib/src/async_tools/future_extensions.dart
// Purpose: The two future shapes the platform repeats: answer-or-nothing, and deliberate fire-and-forget.
// Author: liuchuancong
// Created: 2026-10-10
//
// A source call that times out is a normal outcome, not a crash to log. These helpers make that readable at
// the call site instead of scattering try/catch blocks with the same body.

import 'dart:async';

extension FutureUtils<T> on Future<T> {
  /// This future's value, or null when it does not finish within [timeout].
  ///
  /// Only [TimeoutException] is absorbed; any other error still propagates, because turning a parser bug
  /// into "no data" is how a broken source hides for months.
  Future<T?> nullable(Duration timeout) async {
    try {
      return await this.timeout(timeout);
    } on TimeoutException {
      return null;
    }
  }

  /// This future's value, or [fallback] when it fails with one of [on].
  ///
  /// [on] defaults to [TimeoutException] so widening it stays a deliberate choice rather than a side effect
  /// of a helper that looked convenient.
  Future<T> orFallback(T fallback, {Set<Type> on = const <Type>[TimeoutException]}) {
    return catchError<T>((Object error, StackTrace stack) {
      if (on.contains(error.runtimeType)) {
        return fallback;
      }
      throw error;
    });
  }

  /// Waits for completion and drops the result, recording that the abandonment was deliberate.
  ///
  /// `unawaited` from dart:async does not swallow the rejection - an unobserved error reaches the zone
  /// handler. This observes and drops it, which is what fire-and-forget has to mean to be safe.
  void ignore() {
    unawaited(catchError<void>((Object error, StackTrace stack) => null));
  }
}
