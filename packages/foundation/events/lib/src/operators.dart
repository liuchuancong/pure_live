// Module: lib/src/operators.dart
// Purpose: The stream shapes an event burst needs before a UI can consume it: throttle, coalesce, debounce,
// buffer and staleness.
// Author: liuchuancong
// Created: 2026-10-11
//
// A playback position ticks per frame and a live chat floods; a subscriber that rebuilds on every one of
// those is not slow, it is unusable. Each operator here is *time* bounded - a buffer that only flushes on
// count is an unbounded wait, and a throttle that never lets the last event through loses the value the user
// stopped on. The trailing pass is part of the contract, not an optimisation.

import 'dart:async';

import 'package:pure_live_utils/pure_live_utils.dart';

import 'event_bus.dart';

/// Time-shaping operators over an event stream.
extension EventStreamOperators<T extends AppEvent> on Stream<T> {
  /// Lets the first event through at once, then at most one per [window] - the trailing one being the newest
  /// that arrived, so the last value a producer sent is the value a consumer keeps.
  Stream<T> throttled(Duration window) {
    if (window <= Duration.zero) {
      return this;
    }
    final out = StreamController<T>();
    StreamSubscription<T>? sub;
    Timer? timer;
    T? pending;

    void pump() {
      timer = null;
      final held = pending;
      pending = null;
      if (held == null) {
        return;
      }
      out.add(held);
      timer = Timer(window, pump);
    }

    out.onListen = () {
      sub = listen(
        (event) {
          if (timer == null) {
            out.add(event);
            timer = Timer(window, pump);
            return;
          }
          pending = event;
        },
        onError: out.addError,
        onDone: () {
          timer?.cancel();
          timer = null;
          final held = pending;
          pending = null;
          if (held != null) {
            out.add(held);
          }
          out.close();
        },
      );
    };
    out.onCancel = () {
      timer?.cancel();
      timer = null;
      pending = null;
      return sub?.cancel();
    };
    return out.stream;
  }

  /// At most one event per key per [window], newest wins.
  ///
  /// The single-window throttle drops `position(3:00)` while letting `position(2:10)` through, because it keys
  /// on nothing; a seek bar that lands on the wrong second is what that costs. Each key paces itself, so a
  /// channel switch and a volume change do not silence one another.
  Stream<T> coalescedBy(Duration window, Object? Function(T event) key) {
    if (window <= Duration.zero) {
      return this;
    }
    final out = StreamController<T>();
    final held = <Object?, T>{};
    final timers = <Object?, Timer>{};
    StreamSubscription<T>? sub;

    void arm(Object? name) {
      timers[name] = Timer(window, () {
        timers.remove(name);
        final trailing = held.remove(name);
        if (trailing == null) {
          return;
        }
        out.add(trailing);
        arm(name);
      });
    }

    out.onListen = () {
      sub = listen(
        (event) {
          final name = key(event);
          if (timers.containsKey(name)) {
            held[name] = event;
            return;
          }
          out.add(event);
          arm(name);
        },
        onError: out.addError,
        onDone: () {
          for (final timer in timers.values) {
            timer.cancel();
          }
          timers.clear();
          for (final event in held.values) {
            out.add(event);
          }
          held.clear();
          out.close();
        },
      );
    };
    out.onCancel = () {
      for (final timer in timers.values) {
        timer.cancel();
      }
      timers.clear();
      held.clear();
      return sub?.cancel();
    };
    return out.stream;
  }

  /// Passes an event only once [quiet] has passed with nothing newer. For "the user stopped typing" facts.
  Stream<T> debounced(Duration quiet) {
    if (quiet <= Duration.zero) {
      return this;
    }
    final out = StreamController<T>();
    Timer? timer;
    T? pending;
    StreamSubscription<T>? sub;

    out.onListen = () {
      sub = listen(
        (event) {
          pending = event;
          timer?.cancel();
          timer = Timer(quiet, () {
            timer = null;
            final value = pending;
            pending = null;
            if (value != null) {
              out.add(value);
            }
          });
        },
        onError: out.addError,
        onDone: () {
          timer?.cancel();
          timer = null;
          final value = pending;
          pending = null;
          if (value != null) {
            out.add(value);
          }
          out.close();
        },
      );
    };
    out.onCancel = () {
      timer?.cancel();
      timer = null;
      pending = null;
      return sub?.cancel();
    };
    return out.stream;
  }

  /// Groups events into lists that flush on [window] or after [maxCount], whichever comes first.
  ///
  /// Both triggers are required: window-only means a flood holds the last events in memory, count-only means a
  /// trickle never flushes and the consumer waits for a batch that is already complete.
  Stream<List<T>> buffered({Duration window = const Duration(seconds: 1), int maxCount = 32}) {
    if (window <= Duration.zero || maxCount < 1) {
      throw ArgumentError('buffered needs a positive window and maxCount >= 1');
    }
    final out = StreamController<List<T>>();
    final batch = <T>[];
    Timer? timer;
    StreamSubscription<T>? sub;

    void flush() {
      timer?.cancel();
      timer = null;
      if (batch.isEmpty) {
        return;
      }
      out.add(List<T>.unmodifiable(batch));
      batch.clear();
    }

    out.onListen = () {
      sub = listen(
        (event) {
          batch.add(event);
          if (batch.length >= maxCount) {
            flush();
            return;
          }
          timer ??= Timer(window, flush);
        },
        onError: (Object error, StackTrace stackTrace) {
          flush();
          out.addError(error, stackTrace);
        },
        onDone: () {
          flush();
          out.close();
        },
      );
    };
    out.onCancel = () {
      timer?.cancel();
      timer = null;
      batch.clear();
      return sub?.cancel();
    };
    return out.stream;
  }

  /// Only the events whose [AppEvent.name] is in [names]. A name filter is how one screen listens to three of
  /// the twenty events a session produces without subscribing to the base type and seeing all of them.
  Stream<T> named(Iterable<String> names) {
    final wanted = names.toSet();
    return where((event) => wanted.contains(event.name));
  }

  /// Drops events older than [maxAge], measured against [clock].
  ///
  /// After a resume, a replayed backlog can deliver a "now playing" from ten minutes ago as if it just
  /// happened; the age is on the event, so the check belongs here rather than in each screen.
  Stream<T> fresherThan(Duration maxAge, {Clock? clock}) {
    final now = clock ?? systemClock;
    return where((event) => now().difference(event.at) <= maxAge);
  }
}
