// Public named arguments intentionally keep descriptive names while the
// callback fields remain private implementation details.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/widgets.dart';

/// Identifies the exact playback intent that an application lifecycle pause
/// belongs to. A later room/source change or an explicit user command makes
/// the token stale, so foregrounding the application cannot revive an old
/// player session.
typedef PlaybackLifecyclePauseToken = ({int sessionId, int intentRevision});

typedef LifecyclePauseCallback = Future<PlaybackLifecyclePauseToken?> Function();
typedef LifecycleResumeCallback = Future<bool> Function(PlaybackLifecyclePauseToken token);

/// Owns application lifecycle policy for the single global live player.
///
/// This coordinator intentionally outlives every video widget. Fullscreen,
/// orientation and floating-window transitions rebuild presentation widgets;
/// pairing pause/resume inside one of those widgets loses the resume owner when
/// that widget is disposed. Serializing lifecycle transitions here also avoids
/// a late pause completing after a fast foreground resume.
class PlaybackLifecycleCoordinator with WidgetsBindingObserver {
  PlaybackLifecycleCoordinator({
    required LifecyclePauseCallback pauseForLifecycle,
    required LifecycleResumeCallback resumeFromLifecycle,
    required bool Function() shouldContinueInBackground,
    required bool Function() isAudioOnly,
    required bool Function() isSleepSessionActive,
    required Future<void> Function() commitAudioOnlyPowerSaving,
    required Future<void> Function() prepareAudioOnlyVideoRestore,
    this.hiddenPauseDelay = const Duration(milliseconds: 1500),
  }) : _pauseForLifecycle = pauseForLifecycle,
       _resumeFromLifecycle = resumeFromLifecycle,
       _shouldContinueInBackground = shouldContinueInBackground,
       _isAudioOnly = isAudioOnly,
       _isSleepSessionActive = isSleepSessionActive,
       _commitAudioOnlyPowerSaving = commitAudioOnlyPowerSaving,
       _prepareAudioOnlyVideoRestore = prepareAudioOnlyVideoRestore;

  /// Coalesces the short hidden/paused pair emitted by Android while changing
  /// orientation, entering picture-in-picture or replacing a platform Surface.
  /// A real background transition remains hidden beyond this window and is
  /// still paused according to the configured background policy.
  final Duration hiddenPauseDelay;

  final LifecyclePauseCallback _pauseForLifecycle;
  final LifecycleResumeCallback _resumeFromLifecycle;
  final bool Function() _shouldContinueInBackground;
  final bool Function() _isAudioOnly;
  final bool Function() _isSleepSessionActive;
  final Future<void> Function() _commitAudioOnlyPowerSaving;
  final Future<void> Function() _prepareAudioOnlyVideoRestore;

  Future<void> _transitionQueue = Future<void>.value();
  PlaybackLifecyclePauseToken? _pendingPause;
  bool _started = false;
  bool _disposed = false;
  bool _hiddenApplied = false;
  Timer? _hiddenPauseTimer;
  int _hiddenPauseRevision = 0;

  AppLifecycleState? get lastState => _lastState;
  AppLifecycleState? _lastState;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _lastState = WidgetsBinding.instance.lifecycleState;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(handleState(state));
  }

  /// Public for deterministic state-machine tests. Calls are serialized in the
  /// same order in which Flutter delivered them.
  Future<void> handleState(AppLifecycleState state) {
    if (_disposed) return Future<void>.value();
    final operation = _transitionQueue.then((_) => _applyState(state));
    _transitionQueue = operation.catchError((Object _, StackTrace _) {});
    return operation;
  }

  Future<void> _applyState(AppLifecycleState state) async {
    if (_disposed) return;
    _lastState = state;

    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        await _enterHiddenState();
        return;
      case AppLifecycleState.resumed:
        await _enterResumedState();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        return;
    }
  }

  Future<void> _enterHiddenState() async {
    if (_hiddenApplied) return;
    _hiddenApplied = true;

    if (_isAudioOnly()) {
      await _commitAudioOnlyPowerSaving();
    }

    if (_shouldContinueInBackground() || _pendingPause != null) return;
    _hiddenPauseTimer?.cancel();
    final revision = ++_hiddenPauseRevision;
    if (hiddenPauseDelay <= Duration.zero) {
      await _applyHiddenPause(revision);
      return;
    }
    _hiddenPauseTimer = Timer(hiddenPauseDelay, () {
      _hiddenPauseTimer = null;
      final operation = _transitionQueue.then((_) => _applyHiddenPause(revision));
      _transitionQueue = operation.catchError((Object _, StackTrace _) {});
    });
  }

  Future<void> _applyHiddenPause(int revision) async {
    if (_disposed ||
        revision != _hiddenPauseRevision ||
        !_hiddenApplied ||
        (_lastState != AppLifecycleState.hidden && _lastState != AppLifecycleState.paused) ||
        _shouldContinueInBackground() ||
        _pendingPause != null) {
      return;
    }
    _pendingPause = await _pauseForLifecycle();
  }

  Future<void> _enterResumedState() async {
    _hiddenPauseTimer?.cancel();
    _hiddenPauseTimer = null;
    _hiddenPauseRevision++;
    _hiddenApplied = false;
    if (_isAudioOnly() && !_isSleepSessionActive()) {
      await _prepareAudioOnlyVideoRestore();
    }

    final token = _pendingPause;
    _pendingPause = null;
    _hiddenApplied = false;
    if (token != null) {
      await _resumeFromLifecycle(token);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _hiddenPauseTimer?.cancel();
    _hiddenPauseTimer = null;
    _hiddenPauseRevision++;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      _started = false;
    }
    _pendingPause = null;
    await _transitionQueue;
  }
}
