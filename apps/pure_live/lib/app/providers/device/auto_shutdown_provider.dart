import 'dart:async' show Timer, unawaited;
import 'dart:io' show exit;

import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/app/providers/window/window_providers.dart' show windowHostProvider;

/// The automatic shutdown timer: a countdown started by the setting, not by
/// the close button. When it reaches zero the app ends, matching the
/// reference's `enableAutoShutDownTime` / `autoShutDownTime`.
final class AutoShutdownState {
  /// Creates a state.
  const AutoShutdownState({this.enabled = false, this.minutes = AutoShutdownController.defaultMinutes, this.remaining});

  /// Whether the countdown is running.
  final bool enabled;

  /// The configured duration in minutes.
  final int minutes;

  /// Time left while the countdown runs; null when it is off.
  final Duration? remaining;

  /// A copy with selected fields replaced.
  AutoShutdownState copyWith({bool? enabled, int? minutes, Duration? remaining, bool clearRemaining = false}) =>
      AutoShutdownState(
        enabled: enabled ?? this.enabled,
        minutes: minutes ?? this.minutes,
        remaining: clearRemaining ? null : remaining ?? this.remaining,
      );
}

/// Owns the automatic shutdown countdown and its persisted choice.
final class AutoShutdownController extends Notifier<AutoShutdownState> {
  /// Minutes for a fresh install, matching the reference.
  static const int defaultMinutes = 120;

  /// The shortest accepted duration.
  static const int minMinutes = 1;

  /// The longest accepted duration (one year).
  static const int maxMinutes = 525600;

  static const String _enabledKey = 'exit.autoShutdown.enabled';
  static const String _minutesKey = 'exit.autoShutdown.minutes';

  Timer? _ticker;
  DateTime? _endAt;
  bool _exiting = false;

  @override
  AutoShutdownState build() {
    ref.onDispose(_cancel);
    final enabled = _readEnabled();
    final minutes = _readMinutes();
    if (enabled) _schedule(minutes);
    return AutoShutdownState(
      enabled: enabled,
      minutes: minutes,
      remaining: enabled ? Duration(minutes: minutes) : null,
    );
  }

  /// Starts or stops the countdown.
  Future<void> setEnabled({required bool enabled}) async {
    state = state.copyWith(
      enabled: enabled,
      remaining: enabled ? Duration(minutes: state.minutes) : null,
      clearRemaining: !enabled,
    );
    await StoragePrefs.setBool(_enabledKey, enabled);
    if (enabled) {
      _schedule(state.minutes);
    } else {
      _cancel();
    }
  }

  /// Changes the duration; a running countdown restarts from the new value.
  Future<void> setMinutes(int minutes) async {
    final normalized = minutes.clamp(minMinutes, maxMinutes);
    state = state.copyWith(
      minutes: normalized,
      remaining: state.enabled ? Duration(minutes: normalized) : null,
      clearRemaining: !state.enabled,
    );
    await StoragePrefs.setInt(_minutesKey, normalized);
    if (state.enabled) _schedule(normalized);
  }

  void _schedule(int minutes) {
    _cancel();
    _endAt = DateTime.now().add(Duration(minutes: minutes));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final end = _endAt;
    if (end == null) return;
    final remaining = end.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _cancel();
      unawaited(_shutdown());
      return;
    }
    if (ref.mounted) state = state.copyWith(remaining: remaining);
  }

  void _cancel() {
    _ticker?.cancel();
    _ticker = null;
    _endAt = null;
  }

  Future<void> _shutdown() async {
    if (_exiting) return;
    _exiting = true;
    if (ref.mounted) state = state.copyWith(enabled: false, clearRemaining: true);
    try {
      await StoragePrefs.setBool(_enabledKey, false);
    } on Object {
      // The timer has already fired; a closed store cannot stop the exit.
    }
    final host = ref.read(windowHostProvider);
    if (host == null) {
      await SystemNavigator.pop();
      return;
    }
    try {
      await host.destroy();
    } on Object {
      // The process still ends below.
    }
    exit(0);
  }

  static bool _readEnabled() {
    try {
      return StoragePrefs.getBool(_enabledKey) ?? false;
    } on Object {
      return false;
    }
  }

  static int _readMinutes() {
    try {
      return (StoragePrefs.getInt(_minutesKey) ?? defaultMinutes).clamp(minMinutes, maxMinutes);
    } on Object {
      return defaultMinutes;
    }
  }
}

/// The automatic shutdown timer.
final autoShutdownProvider = NotifierProvider<AutoShutdownController, AutoShutdownState>(AutoShutdownController.new);
