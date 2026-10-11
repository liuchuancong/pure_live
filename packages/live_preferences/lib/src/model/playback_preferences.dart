import 'package:freezed_annotation/freezed_annotation.dart';

part 'playback_preferences.freezed.dart';
part 'playback_preferences.g.dart';

/// How the player picks a line among the ones a site returns.
enum LinePreference {
  /// Try the site's own order — the first line, then the rest on failure.
  automatic,

  /// Try [PlaybackPreferences.preferredLineId] first, when the site names
  /// one, and fall back to the site's order.
  preferred,
}

/// Playback preferences: what to open with and how hard to recover.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class PlaybackPreferences with _$PlaybackPreferences {
  /// Playback preferences with the shipping defaults.
  const factory PlaybackPreferences({
    /// The preferred quality label, as the site names it; empty means the
    /// highest quality the site offers.
    @Default('') String quality,

    /// The preferred engine id from the playback registry; empty means the
    /// platform's default engine.
    @Default('') String engineId,

    /// Whether the user pinned a line.
    @Default(LinePreference.automatic) LinePreference linePreference,

    /// The pinned line's id (the play line's `lineId`), when the user
    /// pinned one and the site labels its lines.
    @Default('') String preferredLineId,

    /// Whether a failed line advances the recovery ladder (other lines,
    /// then other qualities) instead of stopping at the first failure.
    @Default(true) bool autoRecover,

    /// How many ladder steps a session may take before it gives up,
    /// matching the playback session's default.
    @Default(3) int maxRecoveryAttempts,
  }) = _PlaybackPreferences;

  /// Restores playback preferences from JSON.
  factory PlaybackPreferences.fromJson(Map<String, Object?> json) => _$PlaybackPreferencesFromJson(json);
}
