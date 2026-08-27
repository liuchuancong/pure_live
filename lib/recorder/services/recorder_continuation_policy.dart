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
}
