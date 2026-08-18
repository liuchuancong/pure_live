class RecorderContinuationPolicy {
  const RecorderContinuationPolicy._();

  static bool shouldMonitorAfterExit({required bool manuallyStopped, required bool autoReconnect}) {
    return !manuallyStopped && autoReconnect;
  }
}
