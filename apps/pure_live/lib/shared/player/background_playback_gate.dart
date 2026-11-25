import 'dart:async' show Timer, unawaited;

// The callbacks keep descriptive public names while their fields are private;
// the constructor is the only caller-facing shape.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBindingObserver;

/// The lifecycle gate behind the Android "background playback" switch.
///
/// The reference waits 1.5 s after the app really leaves the foreground
/// before pausing, so an orientation change, a PiP handoff or a transient
/// activity rebuild never stops a playing room. A page calls this gate from
/// its [WidgetsBindingObserver]; the page decides what "playing" and
/// "normal presentation" mean and supplies the pause/resume calls.
final class BackgroundPlaybackGate {
  /// Creates a gate; it is active only on Android, where the reference
  /// exposes the switch.
  BackgroundPlaybackGate({
    required bool Function() backgroundEnabled,
    required bool Function() shouldPause,
    required Future<void> Function() pause,
    required bool Function() canResume,
    required Future<void> Function() resume,
    this.delay = const Duration(milliseconds: 1500),
  }) : _backgroundEnabled = backgroundEnabled,
       _shouldPause = shouldPause,
       _pause = pause,
       _canResume = canResume,
       _resume = resume;

  /// Whether the viewer chose to keep playing in the background.
  final bool Function() _backgroundEnabled;

  /// Whether the surface is actually playing in a visible (non-PiP) mode.
  final bool Function() _shouldPause;

  /// Pauses for the lifecycle; the page remembers which session it was.
  final Future<void> Function() _pause;

  /// Whether the same session is still open and paused on return.
  final bool Function() _canResume;

  /// Resumes the session this gate paused.
  final Future<void> Function() _resume;

  /// The coalescing window; see the class comment.
  final Duration delay;

  Timer? _timer;
  bool _disposed = false;
  bool _foreground = true;
  bool _pauseCycle = false;
  int _generation = 0;
  Future<void> _operations = Future<void>.value();
  bool get _active => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Feeds one lifecycle event. Call from `didChangeAppLifecycleState`.
  void handleLifecycle(AppLifecycleState state) {
    if (!_active || _disposed) return;
    _generation++;
    switch (state) {
      case AppLifecycleState.inactive:
        _cancelTimer();
      case AppLifecycleState.resumed:
        _foreground = true;
        _cancelTimer();
        _resumeIfPaused();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _foreground = false;
        _schedulePause();
      case AppLifecycleState.detached:
        _foreground = false;
        _cancelTimer();
    }
  }

  /// Cancels a pending pause when the owning page goes away.
  void dispose() {
    _disposed = true;
    _generation++;
    _cancelTimer();
  }

  void _schedulePause() {
    _cancelTimer();
    if (_backgroundEnabled() || (!_shouldPause() && !_pauseCycle)) return;
    final generation = _generation;
    _timer = Timer(delay, () {
      _timer = null;
      if (!_current(generation) || _foreground || _backgroundEnabled()) return;
      if (!_shouldPause() && !_pauseCycle) return;
      _pauseCycle = true;
      unawaited(_enqueue(_pause));
    });
  }

  void _resumeIfPaused() {
    if (!_pauseCycle) return;
    final generation = _generation;
    unawaited(
      _enqueue(() async {
        if (!_current(generation) || !_foreground || !_canResume()) return;
        await _resume();
        if (_current(generation) && _foreground) _pauseCycle = false;
      }),
    );
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _operations.then((_) => operation()).catchError((Object _) {});
    _operations = result;
    return result;
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
