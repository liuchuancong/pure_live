import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:media_kit/ffi/ffi.dart';
import 'package:media_kit/generated/libmpv/bindings.dart' as generated;
import 'native_event_loop_bindings.dart' as native;

/// Owns one mpv handle, its event buffer, and its native wakeup registration.
final class NativeEventLoop implements Finalizable {
  NativeEventLoop._(this._mpv, this.handle, this._callback);

  static final _finalizer = NativeFinalizer(Native.addressOf(native.finalize));
  static final _callbackZoneKey = Object();

  final generated.MPV _mpv;
  final Pointer<generated.mpv_handle> handle;
  final Future<void> Function(Pointer<generated.mpv_event>) _callback;
  final RawReceivePort _port = RawReceivePort();
  final Completer<void> _destroyed = Completer<void>();
  Pointer<Void> _owner = nullptr;
  bool _closing = false;
  bool _draining = false;
  bool _pending = false;
  Future<void>? _drainFuture;
  Future<void>? _disposeFuture;

  static Future<NativeEventLoop> create(
    DynamicLibrary library,
    Future<void> Function(Pointer<generated.mpv_event>) callback, {
    Map<String, String> options = const {},
  }) async {
    final mpv = generated.MPV(library);
    final handle = mpv.mpv_create();
    if (handle == nullptr) throw StateError('mpv_create failed');
    final loop = NativeEventLoop._(mpv, handle, callback);
    // RawReceivePort otherwise drops the caller's error-handling zone.
    loop._port.handler = Zone.current.bindUnaryCallbackGuarded(loop._onMessage);
    try {
      loop._owner = native.create(
        handle.cast(),
        library.lookup('mpv_set_wakeup_callback'),
        library.lookup('mpv_terminate_destroy'),
        NativeApi.postCObject.cast(),
        loop._port.sendPort.nativePort,
      );
      if (loop._owner == nullptr) {
        throw StateError('Could not allocate the native player event loop');
      }
      _finalizer.attach(loop, loop._owner, detach: loop);
      for (final entry in options.entries) {
        final name = entry.key.toNativeUtf8();
        final value = entry.value.toNativeUtf8();
        try {
          // Some libmpv builds omit optional options (e.g. osc).
          mpv.mpv_set_option_string(handle, name.cast(), value.cast());
        } finally {
          calloc.free(name);
          calloc.free(value);
        }
      }
      final result = mpv.mpv_initialize(handle);
      if (result < 0) throw StateError('mpv_initialize failed: $result');
      return loop;
    } catch (_) {
      if (loop._owner != nullptr) {
        await loop.dispose();
      } else {
        loop._port.close();
        mpv.mpv_terminate_destroy(handle);
      }
      rethrow;
    }
  }

  void _onMessage(dynamic message) {
    if (message == 0) {
      if (!_destroyed.isCompleted) _destroyed.complete();
      return;
    }
    if (_closing) return;
    _pending = true;
    if (_draining) return;
    _draining = true;
    final idle = Completer<void>();
    _drainFuture = idle.future;
    unawaited(_drain(idle));
  }

  Future<void> _drain(Completer<void> idle) async {
    try {
      do {
        _pending = false;
        while (!_closing) {
          final event = _mpv.mpv_wait_event(handle, 0);
          if (event == nullptr ||
              event.ref.event_id == generated.mpv_event_id.MPV_EVENT_NONE) {
            break;
          }
          try {
            // The handler borrows the event buffer until the next wait_event.
            await runZoned(
              () => _callback(event),
              zoneValues: {_callbackZoneKey: this},
            );
          } catch (error, stack) {
            Zone.current.handleUncaughtError(error, stack);
          }
        }
      } while (_pending && !_closing);
    } finally {
      _draining = false;
      idle.complete();
    }
  }

  Future<void> dispose() {
    if (identical(Zone.current[_callbackZoneKey], this)) {
      throw StateError('Cannot await disposal from an mpv event handler');
    }
    if (_disposeFuture != null) return _disposeFuture!;
    _closing = true;
    native.stop(_owner);
    return _disposeFuture = _dispose();
  }

  Future<void> _dispose() async {
    await _drainFuture;
    native.destroy(_owner);
    // Keep the finalizer attached in case the isolate dies during teardown.
    await _destroyed.future;
    _finalizer.detach(this);
    native.release(_owner);
    _owner = nullptr;
    _port.close();
  }
}
