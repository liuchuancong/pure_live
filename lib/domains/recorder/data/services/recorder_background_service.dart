import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pure_live/core/utils/latest_async_value_queue.dart';
import 'package:pure_live/core/utils/i18n.dart';

class RecorderBackgroundException implements Exception {
  const RecorderBackgroundException(this.reason);
  final String reason;
  @override
  String toString() => 'Recorder background protection unavailable ($reason)';
}

/// Recording owns a separate native service, never the playback keep-alive bit.
/// Identity leases prevent an old task's release from stopping a newer writer.
class RecorderBackgroundService {
  static final shared = RecorderBackgroundService();
  RecorderBackgroundService({bool? supported, Future<void> Function(bool)? apply, Future<void> Function()? releaseIdle})
    : _supported = supported ?? Platform.isAndroid,
      _applyOverride = apply,
      _releaseIdleOverride = releaseIdle {
    _transitions = LatestAsyncValueQueue<bool>(_applyState);
    if (_supported && _applyOverride == null) _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const _channel = MethodChannel('pure_live/recorder_background');
  final bool _supported;
  final Future<void> Function(bool)? _applyOverride;
  final Future<void> Function()? _releaseIdleOverride;
  Future<void>? _idleReleaseInFlight;
  final Set<Object> _owners = Set<Object>.identity();
  late final LatestAsyncValueQueue<bool> _transitions;
  bool? _applied;
  bool _disposed = false;
  String? _interruption;
  final Set<Future<void> Function(String)> _interruptionListeners = {};

  int get ownerCount => _owners.length;

  void addInterruptionListener(Future<void> Function(String) listener) => _interruptionListeners.add(listener);
  void removeInterruptionListener(Future<void> Function(String) listener) => _interruptionListeners.remove(listener);

  /// Only a new explicit user start retries a platform-denied/interrupted FGS.
  void allowUserRetry() => _interruption = null;

  /// The native interruption grace period already retains this engine. This
  /// owner only fences final status persistence; it never restarts the FGS.
  void retainForCleanup(Object owner) {
    if (!_disposed) _owners.add(owner);
  }

  Future<void> acquire(Object owner) async {
    if (_disposed) throw const RecorderBackgroundException('closed');
    _owners.add(owner);
    try {
      await _transitions.submit(true);
    } catch (_) {
      _owners.remove(owner);
      if (_owners.isEmpty) {
        try {
          await _transitions.submit(false);
          await _releaseIdleIfUnowned();
        } catch (_) {
          // Preserve the start failure; native startup also owns rollback.
        }
      }
      rethrow;
    }
  }

  Future<void> release(Object owner) async {
    if (!_owners.remove(owner)) return;
    if (_interruption != null && _owners.isNotEmpty) return;
    await _transitions.submit(_owners.isNotEmpty);
    await _releaseIdleIfUnowned();
  }

  /// The first phase stops the FGS, not the engine. Only commit idle after the
  /// whole queue drained: a new owner arriving during false must get its true
  /// transition with the existing native engine binding still held.
  Future<void> _releaseIdleIfUnowned() async {
    if (!_supported || _owners.isNotEmpty || _transitions.isRunning || _applied != false) return;
    final existing = _idleReleaseInFlight;
    if (existing != null) return existing;
    final pending = _releaseIdleNative();
    _idleReleaseInFlight = pending;
    try {
      await pending;
    } finally {
      if (identical(_idleReleaseInFlight, pending)) _idleReleaseInFlight = null;
    }
  }

  Future<void> _releaseIdleNative() async {
    final release = _releaseIdleOverride;
    try {
      if (release != null) {
        await release();
      } else if (_applyOverride == null) {
        await _channel.invokeMethod<void>('releaseIdle');
      }
    } catch (error) {
      throw RecorderBackgroundException(error is PlatformException ? error.code : 'platform_error');
    }
  }

  Future<void> _applyState(bool enabled) async {
    if (enabled && _interruption != null) throw RecorderBackgroundException(_interruption!);
    if (_applied == enabled) return;
    if (_supported) {
      try {
        final apply = _applyOverride;
        if (apply != null) {
          await apply(enabled);
        } else {
          await _channel.invokeMethod<void>('setActive', {
            'active': enabled,
            'title': i18n('recorder_background_notification_title'),
            'text': i18n('recorder_background_notification_text'),
          });
        }
      } catch (error) {
        _applied = null;
        if (enabled) _interruption = 'start_failed';
        throw RecorderBackgroundException(error is PlatformException ? error.code : 'platform_error');
      }
    }
    _applied = enabled;
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'interrupted' || _disposed) return;
    final arguments = call.arguments;
    final reason = arguments is Map ? arguments['reason']?.toString() ?? 'service_stopped' : 'service_stopped';
    await handleInterruption(reason);
  }

  Future<void> handleInterruption(String reason) async {
    if (_disposed || _interruption != null) return;
    _interruption = reason;
    // Native retains a bounded engine lease for graceful Dart finalization.
    // A false transition must still reach native to release that lease.
    _applied = null;
    await Future.wait(_interruptionListeners.toList().map((listener) => listener(reason)));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _interruptionListeners.clear();
    _owners.clear();
    try {
      await _transitions.submit(false);
      await _releaseIdleIfUnowned();
    } finally {
      if (_supported && _applyOverride == null) _channel.setMethodCallHandler(null);
    }
  }
}
