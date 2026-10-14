import 'dart:math' as math;

/// Automatic reconnection behaviour after an abnormal disconnect.
///
/// Delays grow exponentially from `initialDelay` up to `maxDelay`, with an
/// optional jitter fraction so fleets of clients do not reconnect in sync.
/// An explicit `disconnect` never triggers a reconnect regardless of this
/// policy.
final class ReconnectPolicy {
  /// Creates a reconnection policy.
  const new({
    this.enabled = true,
    this.maxAttempts = 10,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2,
    this.jitter = 0,
  }) : assert(multiplier >= 1, 'multiplier must be at least 1'),
       assert(jitter >= 0 && jitter <= 1, 'jitter must be between 0 and 1');

  /// Whether reconnecting is enabled at all.
  final bool enabled;

  /// Maximum retry attempts. A negative value means unlimited retries.
  final int maxAttempts;

  /// Delay before the first retry.
  final Duration initialDelay;

  /// Upper bound for the exponential backoff.
  final Duration maxDelay;

  /// Growth factor applied on every retry.
  final double multiplier;

  /// Fraction (0-1) of randomness subtracted from each delay to avoid
  /// synchronized reconnect storms. 0 disables jitter.
  final double jitter;

  /// Delay to wait before retry number `attempt` (1-based).
  Duration delayForAttempt(int attempt, {math.Random? random}) {
    var delay = _rawDelay(attempt);

    if (jitter > 0) {
      final source = random ?? math.Random();
      final milliseconds = (delay.inMilliseconds * (1 - jitter * source.nextDouble())).ceil();
      delay = Duration(milliseconds: milliseconds.clamp(1, delay.inMilliseconds));
    }

    return delay;
  }

  /// Whether retry number `attempt` may run.
  bool shouldRetry(int attempt) {
    return enabled && (maxAttempts < 0 || attempt <= maxAttempts);
  }

  Duration _rawDelay(int attempt) {
    if (attempt <= 1) {
      return initialDelay;
    }

    final maxMilliseconds = maxDelay.inMilliseconds;
    var milliseconds = initialDelay.inMilliseconds.toDouble();

    for (var i = 1; i < attempt; i++) {
      milliseconds *= multiplier;

      if (milliseconds >= maxMilliseconds) {
        return maxDelay;
      }
    }

    return Duration(milliseconds: milliseconds.ceil().clamp(0, maxMilliseconds));
  }
}
