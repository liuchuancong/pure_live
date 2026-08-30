class RecorderContinuationPolicy {
  const RecorderContinuationPolicy._();

  static bool shouldMonitorAfterExit({required bool manuallyStopped, required bool autoReconnect}) {
    return !manuallyStopped && autoReconnect;
  }

  /// Whether an FFmpeg failure can recover by resolving a fresh live URL and
  /// restarting the recorder.
  ///
  /// CDN I/O errors (including AVERROR(EIO), HTTP 403 and HTTP 404) are
  /// intentionally retryable: signed live URLs expire and platform adapters
  /// may select a different CDN on the next resolve. Local path, permission or
  /// malformed-command failures need user/configuration changes instead.
  static bool shouldRetryFailure({required int errorCode, required String rawLogs}) {
    if (errorCode == -2) return false;

    final normalizedLogs = rawLogs.toLowerCase();
    const fatalMarkers = <String>[
      'permission denied',
      'unable to open output',
      'error opening output',
      'option not found',
      'unrecognized option',
      'unknown protocol',
      'protocol not found',
      'muxer not found',
      'invalid data found when processing output',
      'file exists',
    ];
    return !fatalMarkers.any(normalizedLogs.contains);
  }

  static Duration pollingDelay({
    required int failureCount,
    required int baseSeconds,
    required int maximumSeconds,
    required bool enableBackoff,
  }) {
    final base = baseSeconds.clamp(1, 86400);
    final maximum = maximumSeconds.clamp(base, 86400);
    if (!enableBackoff || failureCount <= 0) return Duration(seconds: base);

    // Cap before shifting to keep corrupt persisted counters bounded.
    final exponent = failureCount.clamp(0, 20);
    final seconds = (base * (1 << exponent)).clamp(base, maximum);
    return Duration(seconds: seconds);
  }

  static Duration reconnectDelay({
    required int failureCount,
    required int configuredBaseSeconds,
    required int configuredMaximumSeconds,
    required bool enableBackoff,
    required bool unexpectedEof,
  }) {
    return pollingDelay(
      failureCount: failureCount,
      baseSeconds: unexpectedEof ? 2 : configuredBaseSeconds,
      maximumSeconds: unexpectedEof ? 15 : configuredMaximumSeconds,
      enableBackoff: enableBackoff,
    );
  }

  /// A live-stream EOF after FFmpeg has opened the media does not prove that
  /// the room went offline. Keep resolving a fresh signed URL with bounded
  /// delay instead of moving the task into the much slower offline poll loop.
  static bool shouldEnterPollingAfterRetryLimit({
    required int retryCount,
    required int maximumRetries,
    required bool unexpectedEof,
  }) {
    if (unexpectedEof) return false;
    return retryCount >= maximumRetries.clamp(1, 100);
  }

  /// Starts acquiring the replacement a few seconds before the active input
  /// reaches its platform refresh boundary. The result is only cached in
  /// memory and remains constrained by the adapter's own invalid-at metadata.
  static Duration leasePrefetchDelay({
    required DateTime now,
    required DateTime refreshAt,
    Duration lead = const Duration(seconds: 5),
  }) {
    final remaining = refreshAt.toUtc().difference(now.toUtc()) - lead;
    return remaining > Duration.zero ? remaining : Duration.zero;
  }

  /// A timer that is already late runs on the next event-loop turn rather than
  /// being silently omitted. This matters after sleep/resume where wall time
  /// may cross the signed transport boundary while Dart timers are suspended.
  static Duration leaseRotationDelay({required DateTime now, required DateTime refreshAt}) {
    final remaining = refreshAt.toUtc().difference(now.toUtc());
    return remaining > Duration.zero ? remaining : Duration.zero;
  }
}
