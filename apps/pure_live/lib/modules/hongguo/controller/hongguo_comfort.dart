import 'package:pure_live/l10n/translations.dart';

/// The session's sleep timer: a wall-clock deadline or a count of episodes
/// left, whichever the viewer set last — the reference's `SleepTimer`, driven
/// by the page's poll rather than a platform handler.
final class HongguoSleepTimer {
  HongguoSleepTimer({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  DateTime? _deadline;
  int _episodesLeft = 0;

  /// Whether a deadline or an episode count is set.
  bool get active => _deadline != null || _episodesLeft > 0;

  /// The episodes still to finish, when the timer counts episodes.
  int get episodesLeft => _episodesLeft;

  /// The time left, when the timer counts minutes.
  Duration? get remaining {
    final deadline = _deadline;
    if (deadline == null) return null;
    final left = deadline.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  /// Stops the timer.
  void cancel() {
    _deadline = null;
    _episodesLeft = 0;
  }

  /// Stops after [minutes].
  void afterMinutes(int minutes) {
    assert(minutes > 0 && minutes <= 180, 'minutes outside 1..180');
    cancel();
    _deadline = _clock().add(Duration(minutes: minutes));
  }

  /// Stops after [count] more episodes finish.
  void afterEpisodes(int count) {
    assert(count > 0 && count <= 10, 'episode count outside 1..10');
    cancel();
    _episodesLeft = count;
  }

  /// Whether the deadline has passed; a pass stops the timer.
  bool poll() {
    final deadline = _deadline;
    if (deadline == null || _clock().isBefore(deadline)) return false;
    cancel();
    return true;
  }

  /// Whether an episode's end stops playback; one that does consumes itself.
  bool episodeEnded() {
    if (poll()) return true;
    if (_episodesLeft <= 0) return false;
    _episodesLeft--;
    return _episodesLeft == 0;
  }

  /// The timer's own words, for the button that set it.
  String label(Translations t) {
    final left = remaining;
    if (left != null) {
      final minutes = (left.inMilliseconds + 59999) ~/ 60000;
      return t.hongguo.sleepMinutes(count: minutes);
    }
    if (_episodesLeft > 0) return t.hongguo.sleepEpisodes(count: _episodesLeft);
    return t.hongguo.sleepOff;
  }
}

/// One episode's automatic-recovery budget: three tries, then the panel —
/// the reference's `RecoveryBudget`. Only an explicit retry resets it.
final class HongguoRecoveryBudget {
  static const List<Duration> delays = [Duration(seconds: 1), Duration(milliseconds: 2500), Duration(seconds: 5)];

  int _attempts = 0;

  /// How many automatic tries have been spent.
  int get attempts => _attempts;

  /// Whether another automatic try is left.
  bool get remaining => _attempts < delays.length;

  /// The delay before the next try, or null when the budget is spent.
  Duration? get delay => remaining ? delays[_attempts] : null;

  /// Spends one try; false when there was none left.
  bool consume() {
    if (!remaining) return false;
    _attempts++;
    return true;
  }

  /// Starts over, on an explicit retry.
  void reset() => _attempts = 0;
}
