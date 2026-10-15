import 'package:freezed_annotation/freezed_annotation.dart';

part 'danmaku_preferences.freezed.dart';
part 'danmaku_preferences.g.dart';

/// Danmaku preferences: whether they show and how they look.
///
/// The numeric fields are deliberately in UI-relative units — an opacity
/// and a font scale in 0..1 multiples, and a share of the picture's height
/// — so no device pixel density or reference size is baked into the stored
/// document. The danmaku renderer owns the conversion.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class DanmakuPreferences with _$DanmakuPreferences {
  /// Danmaku preferences with the shipping defaults.
  const factory DanmakuPreferences({
    /// Whether the danmaku overlay is on.
    @Default(true) bool enabled,

    /// The overlay opacity, 0..1.
    @Default(1) double opacity,

    /// The font size scale, 0.5..2.
    @Default(1) double fontScale,

    /// The share of the picture's height the danmaku may use (rows are
    /// laid out from the top within this band), 0.1..1.
    @Default(1) double area,
  }) = _DanmakuPreferences;

  /// Restores danmaku preferences from JSON.
  factory DanmakuPreferences.fromJson(Map<String, Object?> json) => _$DanmakuPreferencesFromJson(json);
}
