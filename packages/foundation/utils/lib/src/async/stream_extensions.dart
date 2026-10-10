// Module: lib/src/async/stream_extensions.dart
// Purpose: Stream shapes the UI needs: trailing-edge debounce, key-based distinct, first-or-nothing.
//
// Search fields and progress ticks both arrive faster than anything can be done with them. These operators
// exist so each screen does not re-implement a timer and get the cancellation subtly different.

import 'dart:async';

extension StreamUtils<T> on Stream<T> {
  /// Emits the last value of each burst that is followed by [window] of silence.
  ///
  /// The pending timer is cancelled when the subscription goes away; leaving it running would keep work
  /// alive after the widget that asked for it is gone.
  Stream<T> debounce(Duration window) {
    late final StreamController<T> controller;
    Timer? pending;
    T? waiting;
    var hasWaiting = false;
    StreamSubscription<T>? source;

    void flush() {
      pending?.cancel();
      pending = null;
      if (!hasWaiting) {
        return;
      }
      controller.add(waiting as T);
      waiting = null;
      hasWaiting = false;
    }

    controller = StreamController<T>(
      onListen: () {
        source = listen(
          (value) {
            waiting = value;
            hasWaiting = true;
            pending?.cancel();
            pending = Timer(window, flush);
          },
          onError: (Object error, StackTrace stack) => controller.addError(error, stack),
          onDone: () {
            flush();
            controller.close();
          },
        );
      },
      onCancel: () async {
        pending?.cancel();
        pending = null;
        await source?.cancel();
      },
    );
    return controller.stream;
  }

  /// Drops values whose [keyOf] was already seen on this subscription.
  ///
  /// Deduplication is by key rather than by equality because most platform rows carry a volatile field - a
  /// viewer count, a signed url - that changes on every refresh while the row stays the same one.
  Stream<T> distinctByKey<K>(K Function(T value) keyOf) {
    final seen = <K>{};
    return where((value) => seen.add(keyOf(value)));
  }

  /// The first value, or null when the stream closes without one.
  Future<T?> firstOrNull() async {
    final iterator = StreamIterator<T>(this);
    return (await iterator.moveNext()) ? iterator.current : null;
  }
}
