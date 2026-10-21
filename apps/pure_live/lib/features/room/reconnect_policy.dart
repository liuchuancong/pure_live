/// The auto-reconnect ladder: how long to wait before the next attempt and
/// when to stop.
///
/// A stream that fails is retried on its own — the reference's session does
/// the same, and the picture says which attempt is running — so a temporary
/// CDN refusal or a lease that expired mid-play heals without the viewer
/// touching the retry button. The wait doubles from [firstDelay] and stops
/// growing at [maxDelay]; after [maxAttempts] the manual retry stands again,
/// because a room that failed five times in a row is not a hiccup.
final class ReconnectPolicy {
  /// A policy with the shipping ladder.
  const new({
    this.maxAttempts = 5,
    this.firstDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(seconds: 30),
  });

  /// How many automatic attempts a failure streak gets.
  final int maxAttempts;

  /// The wait before the first attempt.
  final Duration firstDelay;

  /// The ceiling the doubling wait stops at.
  final Duration maxDelay;

  /// Whether [attempt] (1-based) is still automatic.
  bool allows(int attempt) => attempt >= 1 && attempt <= maxAttempts;

  /// The wait before [attempt] (1-based): the first delay, doubled per
  /// attempt, capped at [maxDelay].
  Duration delayFor(int attempt) {
    if (attempt <= 1) {
      return firstDelay;
    }
    final doubled = firstDelay * (1 << (attempt - 1).clamp(0, 16));
    return doubled > maxDelay ? maxDelay : doubled;
  }
}
