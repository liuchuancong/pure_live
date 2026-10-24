import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

/// The follows page's auto-refresh: on/off plus the interval in minutes.
/// Both persist under `refresh.follows.*`; the page owns the timer.
typedef FollowsAutoRefresh = ({bool enabled, int minutes});

const FollowsAutoRefresh _defaults = (enabled: false, minutes: 15);

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
      return (enabled: enabled ?? _defaults.enabled, minutes: minutes ?? _defaults.minutes);
    } on Object {
      return _defaults;
    }
  }

  /// Flips the auto refresh, writing the choice through.
  Future<void> setEnabled({required bool value}) => _write((enabled: value, minutes: state.minutes));

  /// Moves the interval, writing the choice through.
  Future<void> setMinutes(int minutes) => _write((enabled: state.enabled, minutes: minutes));

  Future<void> _write(FollowsAutoRefresh next) async {
    state = next;
    try {
      await StoragePrefs.setBool('refresh.follows.auto', next.enabled);
      await StoragePrefs.setInt('refresh.follows.minutes', next.minutes);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }
}

/// The follows page's auto-refresh choice.
final followsAutoRefreshProvider = NotifierProvider<FollowsAutoRefreshController, FollowsAutoRefresh>(
  FollowsAutoRefreshController.new,
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
