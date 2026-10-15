import 'package:freezed_annotation/freezed_annotation.dart';

part 'window_preferences.freezed.dart';
part 'window_preferences.g.dart';

/// Floating (picture-in-picture) window behaviour preferences.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class WindowPreferences with _$WindowPreferences {
  /// Window preferences with the shipping defaults.
  const factory WindowPreferences({
    /// Whether leaving the app opens the floating window with the playing
    /// room.
    @Default(false) bool floatOnLeave,

    /// Whether closing the floating window pauses the room instead of
    /// stopping it.
    @Default(false) bool pauseOnClose,

    /// Whether the floating window stays above other windows.
    @Default(false) bool alwaysOnTop,

    /// The floating window's size as a share of the source video's size,
    /// 0.1..1.
    @Default(0.4) double scale,
  }) = _WindowPreferences;

  /// Restores window preferences from JSON.
  factory WindowPreferences.fromJson(Map<String, Object?> json) => _$WindowPreferencesFromJson(json);
}
