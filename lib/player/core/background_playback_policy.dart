/// Pure policy used by both the Flutter lifecycle observer and Android
/// keep-alive handling.
///
/// Manual audio-only mode is a presentation/power-saving choice for the
/// current room. It must not silently override the user's background playback
/// switch. An explicitly started sleep session remains a separate intent: it
/// is expected to keep playing until its timer stops the room.
class BackgroundPlaybackPolicy {
  const BackgroundPlaybackPolicy._();

  static bool shouldContinue({
    required bool backgroundPlaybackEnabled,
    required bool sleepSessionActive,
    required bool audioOnlySessionActive,
  }) {
    // Keep [audioOnlySessionActive] in this policy boundary so callers cannot
    // accidentally reintroduce an audio-only bypass outside the shared
    // decision point when synchronizing lifecycle and native keep-alive state.
    return backgroundPlaybackEnabled || sleepSessionActive;
  }
}
