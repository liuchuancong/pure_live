import 'package:freezed_annotation/freezed_annotation.dart';

part 'iptv_preferences.freezed.dart';
part 'iptv_preferences.g.dart';

/// IPTV preferences: how the channel library and its guides keep current.
///
/// Every interval here is a *staleness* threshold rather than a timer: the app
/// asks "is anything older than this" when it starts and when it returns to
/// the foreground, and nothing schedules a wake-up of its own. That keeps a
/// backgrounded app from downloading playlists nobody is looking at, and it
/// means a long interval is not a promise of silence — opening the app after a
/// week refreshes within the second.
///
/// [lineHealthFreshness] is the one preference of this group that changes what
/// is *played* rather than what is downloaded: how long a probe's verdict is
/// believed before the ranking falls back to the playlist's own order.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class IptvPreferences with _$IptvPreferences {
  /// IPTV preferences with the shipping defaults.
  const factory IptvPreferences({
    /// Whether imported playlists with a recorded address are re-downloaded
    /// when they have gone stale.
    @Default(true) bool autoSyncPlaylists,

    /// How old a playlist import must be before it is refreshed.
    @Default(Duration(hours: 24)) Duration playlistSyncInterval,

    /// Whether guide sources are re-downloaded when they have gone stale.
    @Default(true) bool autoSyncGuides,

    /// How old a guide refresh must be before it is re-downloaded. Shorter
    /// than the playlists': a programme list covers the next day or two.
    @Default(Duration(hours: 6)) Duration guideSyncInterval,

    /// How long a line-probe verdict is believed before it is treated as
    /// "nobody knows" again. Yesterday's dead mirror is tonight's unknown.
    @Default(Duration(hours: 12)) Duration lineHealthFreshness,
  }) = _IptvPreferences;

  /// Restores IPTV preferences from JSON.
  factory IptvPreferences.fromJson(Map<String, Object?> json) => _$IptvPreferencesFromJson(json);
}
