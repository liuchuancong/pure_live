import 'dart:async';

import 'package:audio_session/audio_session.dart' show AudioInterruptionEvent, AudioInterruptionType;
import 'package:flutter/widgets.dart';
import 'package:pure_live/system/playback/audio_focus_port.dart';

/// The room's side of the focus: what an interruption may do to playback.
///
/// The controller implements it; the room's audio focus calls these, and its
/// own pause/resume do not count as the viewer's.
abstract interface class RoomAudioTarget {
  /// Whether sound is coming out right now (opening, buffering or playing).
  bool get sounding;

  /// Whether the room is paused.
  bool get paused;

  /// Whether the room is muted (a duck leaves the level alone then).
  bool get muted;

  /// The room's volume, 0..1.
  double get volume;

  /// Pauses without touching the focus's bookkeeping.
  void pause();

  /// Resumes without touching the focus's bookkeeping.
  void resume();

  /// Sets the volume 0..1 without touching the focus's bookkeeping.
  void setVolume(double volume);
}

/// The room's audio focus: it asks the system for the focus when playback
/// starts and gives it back when the room closes; then
/// - a call or an alarm pauses the room, and its end resumes it when the
///   focus paused it and the viewer did nothing meanwhile — or waits for the
///   app to come back when the room may not play in the background;
/// - a prompt lowers the volume to [duckFactor] until it ends, then restores
///   the volume the viewer had unless they changed it meanwhile;
/// - another player taking the focus for good pauses the room with no resume,
///   and playing again asks for the focus again;
/// - unplugged headphones pause the room for good.
///
/// Events run in order, one at a time; a failure on the platform side never
/// stops playback.
final class RoomAudioFocus with WidgetsBindingObserver {
  /// Follows [target] on [port]; [mayPlayNow] says whether the room may play
  /// where the app is now (null: always).
  new({required this.target, required this.port, this.mayPlayNow, this.onError});

  /// How far a prompt lowers the volume.
  static const duckFactor = 0.2;

  /// The room's player.
  final RoomAudioTarget target;

  /// The system's side.
  final AudioFocusPort port;

  /// Whether the room may play now (the background-play setting's rule).
  final bool Function()? mayPlayNow;

  /// Where a platform failure is logged; playback goes on regardless.
  final void Function(Object error, StackTrace stack)? onError;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  Future<void> _queue = Future.value();
  bool _started = false;
  bool _disposed = false;
  bool _observing = false;

  /// The focus is held (asked for and not lost for good).
  bool _active = false;

  /// The focus paused the room; the end of the interruption resumes it.
  bool _pausedByFocus = false;

  /// A pause whose end resumes is under way.
  bool _pausingToResume = false;

  /// The interruption ended where the room may not play: resume when back.
  bool _resumeWhenBack = false;

  /// While a prompt plays: the volume before and the lowered one.
  double? _volumeBeforeDuck;
  double? _duckedVolume;

  /// Whether the room is paused by a call or another app and resumes when it
  /// ends (or when the app is back).
  bool get pausedUntilInterruptionEnds => _pausingToResume || _pausedByFocus || _resumeWhenBack;

  /// Starts following the system and asks for the focus.
  void start() {
    if (_started || _disposed) {
      return;
    }
    _started = true;
    _subscriptions
      ..add(port.interruptions.listen(_onInterruption, onError: _onPortError))
      ..add(port.becomingNoisy.listen((_) => _enqueue(_onNoisy), onError: _onPortError));
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
    ensureActive();
  }

  /// The viewer played (or paused): whatever the focus did is no longer ours
  /// to undo, and a resumed room asks for the focus again.
  void onUserChanged() {
    _pausedByFocus = false;
    _resumeWhenBack = false;
    ensureActive();
  }

  /// Asks for the focus if playback may sound and it is not held.
  void ensureActive() {
    if (_disposed || target.paused || _active) {
      return;
    }
    _active = true;
    _enqueue(() => _activate(active: true));
  }

  void _onPortError(Object error, StackTrace stack) => onError?.call(error, stack);

  void _onInterruption(AudioInterruptionEvent event) {
    switch ((event.begin, event.type)) {
      case (true, AudioInterruptionType.pause):
        _enqueue(() => _pauseForFocus(resume: true));
      case (true, AudioInterruptionType.unknown):
        _active = false;
        _enqueue(() => _pauseForFocus(resume: false));
      case (true, AudioInterruptionType.duck):
        _enqueue(_duck);
      case (false, AudioInterruptionType.duck):
        _enqueue(_unduck);
      case (false, _):
        _enqueue(_interruptionEnded);
    }
  }

  Future<void> _pauseForFocus({required bool resume}) async {
    _resumeWhenBack = false;
    if (!target.sounding) {
      return;
    }
    _pausingToResume = resume;
    try {
      target.pause();
    } finally {
      _pausingToResume = false;
    }
    _pausedByFocus = resume && target.paused;
  }

  Future<void> _interruptionEnded() async {
    if (!_pausedByFocus) {
      return;
    }
    _pausedByFocus = false;
    if (!target.paused) {
      return;
    }
    if (mayPlayNow?.call() ?? true) {
      target.resume();
    } else {
      _resumeWhenBack = true;
    }
  }

  Future<void> _duck() async {
    if (_duckedVolume != null || target.muted) {
      return;
    }
    final before = target.volume;
    final lowered = before * duckFactor;
    _volumeBeforeDuck = before;
    _duckedVolume = lowered;
    target.setVolume(lowered);
  }

  Future<void> _unduck() async {
    final before = _volumeBeforeDuck;
    final lowered = _duckedVolume;
    _volumeBeforeDuck = null;
    _duckedVolume = null;
    if (before == null || lowered == null) {
      return;
    }
    // A volume the viewer chose meanwhile stays.
    if ((target.volume - lowered).abs() < 1e-6) {
      target.setVolume(before);
    }
  }

  Future<void> _onNoisy() async {
    _pausedByFocus = false;
    _resumeWhenBack = false;
    if (target.sounding) {
      target.pause();
    }
  }

  Future<void> _activate({required bool active}) async {
    try {
      await port.activate(active: active);
    } on Object catch (error, stack) {
      onError?.call(error, stack);
    }
  }

  void _enqueue(Future<void> Function() operation) {
    _queue = _queue.then((_) async {
      if (_disposed) {
        return;
      }
      try {
        await operation();
      } on Object catch (error, stack) {
        onError?.call(error, stack);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onAppResumed();
    }
  }

  /// The app is back on screen: resume what an interruption left paused here.
  void onAppResumed() {
    if (!_resumeWhenBack) {
      return;
    }
    _enqueue(() async {
      if (!_resumeWhenBack) {
        return;
      }
      _resumeWhenBack = false;
      if (target.paused) {
        target.resume();
      }
    });
  }

  /// Stops following and gives the focus back.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
    }
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    await _queue;
    _disposed = true;
    if (_active) {
      _active = false;
      await _activate(active: false);
    }
  }
}
