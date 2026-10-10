// Module: lib/src/retry_policy.dart
// Purpose: The wait between attempts, including the wait the server asked for.
// Author: liuchuancong
// Created: 2026-10-11
//
// A fixed backoff curve is a guess. A 429 that carries `Retry-After: 30` is not a guess, and retrying on the
// curve instead hammers an endpoint that has already said it is full - which is how a fan-out search turns a
// rate limit into a ban. The HTTP-date form is parsed here rather than through dart:io's HttpDate because this
// package has to stay loadable on web.

import 'failure.dart';

/// How many attempts, how long between them, and whether to obey the server.
final class RetryPolicy {
  const RetryPolicy({
    this.attempts = 3,
    this.baseDelay = const Duration(milliseconds: 300),
    this.backoff = 2.0,
    this.maxDelay = const Duration(seconds: 15),
    this.respectsRetryAfter = true,
    this.retryAfterCeiling = const Duration(minutes: 2),
  }) : assert(attempts >= 1, 'an attempt budget below one cannot run a request'),
       assert(backoff >= 1.0, 'a backoff below one waits less with every failure');

  /// Total calls, including the first.
  final int attempts;

  /// The wait before the second attempt.
  final Duration baseDelay;

  /// How much the wait grows per round, before [maxDelay] clamps it.
  final double backoff;

  /// The ceiling on the curve. A server hint can exceed it up to [retryAfterCeiling].
  final Duration maxDelay;

  /// Whether a `Retry-After` on a 429 or 503 replaces the curve for that round.
  final bool respectsRetryAfter;

  /// The longest hint worth obeying. Past this the request should have been dropped, not queued: an endpoint
  /// that asks for an hour is telling the caller to stop, not to wait.
  final Duration retryAfterCeiling;

  /// The curve's wait after the [attempt]-th failure (1-based).
  Duration scheduled(int attempt) {
    if (attempt <= 1) {
      return baseDelay;
    }
    var wait = baseDelay;
    for (var round = 2; round <= attempt; round++) {
      final grown = Duration(microseconds: (wait.inMicroseconds * backoff).round());
      wait = grown > maxDelay ? maxDelay : grown;
    }
    return wait;
  }

  /// The wait to apply for [error], given the curve's [fallback].
  ///
  /// This is the shape `retryAsync`'s `delayFor` hook wants, so one policy drives both the ordinary backoff
  /// and the server-instructed one.
  Duration waitAfter(Object error, Duration fallback) {
    if (!respectsRetryAfter || error is! NetworkFailure) {
      return _clamp(fallback);
    }
    final hint = error.retryAfter;
    if (hint == null) {
      return _clamp(fallback);
    }
    if (hint > retryAfterCeiling) {
      // Refuse the retry rather than sleep an unbounded time inside a request the caller is awaiting.
      return retryAfterCeiling;
    }
    return hint;
  }

  /// The hook for `retryAsync(delayFor: ...)`.
  Duration Function(Object error, Duration scheduled) get asDelayFor => waitAfter;

  Duration _clamp(Duration value) => value > maxDelay ? maxDelay : value;

  @override
  String toString() =>
      'RetryPolicy($attempts attempts, ${baseDelay.inMilliseconds}ms x$backoff <=${maxDelay.inMilliseconds}ms'
      '${respectsRetryAfter ? ', obeys Retry-After <=${retryAfterCeiling.inSeconds}s' : ''})';
}

/// The gap a `Retry-After` value asks for, or null when the header is absent or unreadable.
///
/// Both forms are legal (RFC 9110 section 10.2.3): a delay in seconds, and an HTTP-date. The date form is
/// measured against [now], not against the wall clock inside this function, so an injected clock keeps a test
/// deterministic - and a server whose clock is ahead yields a non-negative wait instead of a negative one.
Duration? parseRetryAfter(String? value, {required DateTime now, DateTime? serverDate}) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  final seconds = int.tryParse(text);
  if (seconds != null) {
    return seconds < 0 ? Duration.zero : Duration(seconds: seconds);
  }
  final target = parseHttpDate(text);
  if (target == null) {
    return null;
  }
  // Skew between the two clocks is the common case; a server date header, when present, is the reference.
  final reference = now.add(_skew(now, serverDate));
  final wait = target.difference(reference);
  return wait.isNegative ? Duration.zero : wait;
}

Duration _skew(DateTime now, DateTime? serverDate) => serverDate == null ? Duration.zero : serverDate.difference(now);

const List<String> _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `Sun, 06 Nov 1994 08:49:37 GMT`, the only date format HTTP headers may carry (RFC 9110 section 5.6.7).
/// Returns UTC. Null for anything else, including the two obsolete forms a legacy proxy may still send.
DateTime? parseHttpDate(String? text) {
  final value = text?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  final comma = value.indexOf(',');
  final body = comma < 0 ? value : value.substring(comma + 1);
  final parts = body.trim().split(RegExp(r'\s+'));
  if (parts.length < 5) {
    return null;
  }
  final day = int.tryParse(parts[0]);
  final month = _monthNames.indexOf(_title(parts[1]));
  final year = int.tryParse(parts[2]);
  final clock = parts[3].split(':');
  if (day == null || month < 0 || year == null || clock.length < 3) {
    return null;
  }
  final hour = int.tryParse(clock[0]);
  final minute = int.tryParse(clock[1]);
  final second = int.tryParse(clock[2]);
  if (hour == null || minute == null || second == null) {
    return null;
  }
  try {
    return DateTime.utc(year, month + 1, day, hour, minute, second);
  } on ArgumentError {
    return null;
  }
}

String _title(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
