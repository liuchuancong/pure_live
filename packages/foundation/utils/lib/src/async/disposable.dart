// Module: lib/src/async/disposable.dart
// Purpose: Collect the handles one object owns and release them all, exactly once, in reverse order.
// Author: liuchuancong
// Created: 2026-10-10
//
// Every long-lived object in this repository ends up owning some mix of subscriptions, timers and store
// handles, and the release rule is the same each time: paired, idempotent, and never silently dropped.
// Without one collector, each package writes its own dispose and each one gets the error path wrong in a
// different way - usually by stopping at the first failure so the rest leak.

import 'dart:async';

/// Something with a limited lifetime that must be released.
abstract interface class Disposable {
  /// Releases what this object owns. Must be safe to call more than once.
  void dispose();
}

typedef ReleaseAction = FutureOr<void> Function();

/// Collects [ReleaseAction]s and runs them once, in reverse registration order.
///
/// Reverse because a handle created later usually depends on one created earlier: closing the store before
/// the watcher that flushes into it loses the last write.
final class Disposer implements Disposable {
  final List<ReleaseAction> _releases = <ReleaseAction>[];
  bool _disposed = false;

  /// True after [dispose] has run; adding to a disposed collector is a bug at the call site.
  bool get isDisposed => _disposed;

  /// Number of actions still owed.
  int get pendingCount => _releases.length;

  /// Registers [action] to run on [dispose].
  void add(ReleaseAction action) {
    if (_disposed) {
      throw StateError('Disposer already disposed; a handle registered after dispose will never be freed');
    }
    _releases.add(action);
  }

  /// Registers a subscription, ignoring null so `addSubscription(sub ?? ...)` is not needed at the call
  /// site.
  void addSubscription(StreamSubscription<Object?>? subscription) {
    if (subscription == null) {
      return;
    }
    add(subscription.cancel);
  }

  /// Runs every registered action.
  ///
  /// All of them run even when one throws: a failing cancel must not strand the handles behind it. The first
  /// error is rethrown afterwards so the failure still reaches the caller instead of being swallowed.
  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    Object? firstError;
    StackTrace? firstStack;
    for (final action in _releases.reversed) {
      try {
        action();
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    _releases.clear();
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStack!);
    }
  }
}
