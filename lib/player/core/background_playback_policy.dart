/// Pure policy used by both the Flutter lifecycle observer and Android
/// keep-alive handling. Keeping this decision in one place prevents audio-only
/// playback from being treated like an ordinary foreground video.
class BackgroundPlaybackPolicy {
  const BackgroundPlaybackPolicy._();

  static bool shouldContinue({
    required bool backgroundPlaybackEnabled,
    required bool sleepSessionActive,
    required bool audioOnlySessionActive,
  }) {
    return backgroundPlaybackEnabled || sleepSessionActive || audioOnlySessionActive;
  }
}
