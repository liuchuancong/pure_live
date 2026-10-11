import 'package:freezed_annotation/freezed_annotation.dart';

part 'tv_preferences.freezed.dart';
part 'tv_preferences.g.dart';

/// TV navigation preferences: how a remote control moves through the UI.
///
/// Only navigation lives here — the TV layouts themselves belong to
/// `live_uikit`, and the playback behaviour behind the controls belongs to
/// the playback group.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class TvPreferences with _$TvPreferences {
  /// TV preferences with the shipping defaults.
  const factory TvPreferences({
    /// Whether the UI restores the last focused control when a page is
    /// entered again, instead of focusing its first control.
    @Default(true) bool focusMemory,

    /// How much a focused control grows, as a scale factor; 1 keeps every
    /// control at its layout size.
    @Default(1.08) double focusScale,

    /// Whether holding the d-pad's left/right key seeks in the live
    /// buffer, instead of moving focus.
    @Default(false) bool longPressSeek,
  }) = _TvPreferences;

  /// Restores TV preferences from JSON.
  factory TvPreferences.fromJson(Map<String, Object?> json) => _$TvPreferencesFromJson(json);
}
