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
      'invalid argument',
      'no such file',
      'permission denied',
      'unable to open output',
      'error opening output',
    ];
    return !fatalMarkers.any(normalizedLogs.contains);
  }
}
