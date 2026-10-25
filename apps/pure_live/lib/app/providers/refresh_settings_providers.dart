import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

/// The follows page's auto-refresh: on/off, the interval in minutes, and
/// whether returning to the app refreshes once. All persist under
/// `refresh.follows.*`; the page owns the timers.
typedef FollowsAutoRefresh = ({bool enabled, int minutes, bool onResume});

/// The reference's fresh-install defaults: periodic refresh off, every 30
/// minutes when enabled, and one foreground pass on return.
const FollowsAutoRefresh _defaults = (enabled: false, minutes: 30, onResume: true);

/// The reference clamps the stored interval to five minutes … six hours on
/// every read, so an imported or edited value cannot arm an out-of-range
/// clock.
const int kRefreshIntervalMin = 5;
const int kRefreshIntervalMax = 360;

/// The refresh choices the interval select offers — the reference's twelve
/// (`settings_catalog.dart` `followRefreshMinutes`): five minutes up to six
/// hours.
const List<int> kRefreshIntervalChoices = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 360];

/// Owns the follows page's auto-refresh choice.
final class FollowsAutoRefreshController extends Notifier<FollowsAutoRefresh> {
  @override
  FollowsAutoRefresh build() {
    try {
      final enabled = StoragePrefs.getBool('refresh.follows.auto');
      final minutes = StoragePrefs.getInt('refresh.follows.minutes');
      final onResume = StoragePrefs.getBool('refresh.follows.onResume');
      return (
        enabled: enabled ?? _defaults.enabled,
        minutes: _normalizeMinutes(minutes),
        onResume: onResume ?? _defaults.onResume,
      );
    } on Object {
      return _defaults;
    }
  }

  /// Keeps the interval inside the reference's 5–360 range; a missing value
  /// uses the reference's 30-minute fresh-install default.
  static int _normalizeMinutes(int? minutes) {
    if (minutes == null) return _defaults.minutes;
    return minutes.clamp(kRefreshIntervalMin, kRefreshIntervalMax);
  }

  /// Flips the auto refresh, writing the choice through.
  Future<void> setEnabled({required bool value}) =>
      _write((enabled: value, minutes: state.minutes, onResume: state.onResume));

  /// Moves the interval, writing the choice through.
  Future<void> setMinutes(int minutes) =>
      _write((enabled: state.enabled, minutes: _normalizeMinutes(minutes), onResume: state.onResume));

  /// Flips the one-shot foreground refresh, writing the choice through.
  Future<void> setOnResume({required bool value}) =>
      _write((enabled: state.enabled, minutes: state.minutes, onResume: value));

  Future<void> _write(FollowsAutoRefresh next) async {
    state = next;
    try {
      await StoragePrefs.setBool('refresh.follows.auto', next.enabled);
      await StoragePrefs.setInt('refresh.follows.minutes', next.minutes);
      await StoragePrefs.setBool('refresh.follows.onResume', next.onResume);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }
}

/// The follows page's auto-refresh choice.
final followsAutoRefreshProvider = NotifierProvider<FollowsAutoRefreshController, FollowsAutoRefresh>(
  FollowsAutoRefreshController.new,
);

/// The reference's refresh queue bounds: one room at a time … twenty at
/// once, with four recommended for a normal list.
const int kMaxConcurrentRefreshMin = 1;
const int kMaxConcurrentRefreshMax = 20;
const int kMaxConcurrentRefreshDefault = 4;

/// Owns how many followed rooms are refreshed at once. Persists under
/// `refresh.maxConcurrent`; every refresh pass reads it when it starts.
final class MaxConcurrentRefreshController extends Notifier<int> {
  @override
  int build() {
    try {
      final stored = StoragePrefs.getInt('refresh.maxConcurrent');
      if (stored == null) return kMaxConcurrentRefreshDefault;
      return stored.clamp(kMaxConcurrentRefreshMin, kMaxConcurrentRefreshMax);
    } on Object {
      return kMaxConcurrentRefreshDefault;
    }
  }

  /// Moves the bound, writing the choice through; running passes keep the
  /// batch they started with.
  Future<void> set(int value) async {
    final next = value.clamp(kMaxConcurrentRefreshMin, kMaxConcurrentRefreshMax);
    state = next;
    try {
      await StoragePrefs.setInt('refresh.maxConcurrent', next);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }
}

/// The refresh queue bound.
final maxConcurrentRefreshProvider = NotifierProvider<MaxConcurrentRefreshController, int>(
  MaxConcurrentRefreshController.new,
);

/// The watch history's cap; the oldest records past it leave on every
/// write. Persists under `history.limit`.
final class HistoryLimitController extends Notifier<int> {
  /// The floor and ceiling the slider offers.
  static const int min = 100;
  static const int max = 1000;
  static const int fallback = 500;

  /// The caps the limit select offers, inside [min] and [max].
  static const List<int> choices = [min, 200, 300, fallback, 800, max];

  @override
  int build() {
    try {
      final stored = StoragePrefs.getInt('history.limit');
      if (stored == null) return fallback;
      return stored.clamp(min, max);
    } on Object {
      return fallback;
    }
  }

  /// Moves the cap, writing the choice through; the repository's next trim
  /// reads it back.
  Future<void> setLimit(int limit) async {
    final next = limit.clamp(min, max);
    state = next;
    try {
      await StoragePrefs.setInt('history.limit', next);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }
}

/// The watch history's cap.
final historyLimitProvider = NotifierProvider<HistoryLimitController, int>(HistoryLimitController.new);
