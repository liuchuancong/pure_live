import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/tokens/seed_token.dart';
import 'package:live_uikit/src/styling/tokens/theme_algorithm.dart';

part 'live_config.freezed.dart';
part 'live_config.g.dart';

/// The light/dark policy, mirroring Ant's `theme` + `algorithm` choice.
enum UiBrightnessMode {
  /// Follow the platform's current setting.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark,
}

/// The layout density, mapping onto Ant's default vs compact algorithms.
enum UiDensity {
  /// Tighter controls and spacing (Ant's compact algorithm).
  compact,

  /// The shipping default.
  comfortable,

  /// Taller controls and more air (touch and TV).
  spacious,
}

/// Maps a [Color] to and from its 32-bit ARGB integer for JSON storage.
class ColorConverter implements JsonConverter<Color?, int?> {
  /// A colour converter.
  const ColorConverter();

  @override
  Color? fromJson(int? value) => value == null ? null : Color(value);

  @override
  int? toJson(Color? color) => color?.toARGB32();
}

/// The application-level theme configuration — the object a settings screen or
/// preferences store maps onto, and what `LiveConfigProvider` turns into a
/// [SeedToken] plus a list of theme algorithms.
///
/// This is deliberately the *choice* surface (which seed values differ, which
/// algorithms run, the global font and transparency), separated from the
/// resolved seed and design tokens so a change here is one object rather
/// than a re-theme of the whole tree. It is JSON-serialisable so the whole
/// theme choice can be persisted as one record.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class UiConfig with _$UiConfig {
  /// A configuration; the defaults reproduce Ant Design out of the box.
  const factory UiConfig({
    /// The active design language. `token` is the shared base; any other value
    /// names the widget library that renders the controls.
    @Default(LiveDesignLanguage.token) LiveDesignLanguage language,

    /// The light/dark policy.
    @Default(UiBrightnessMode.system) UiBrightnessMode brightness,

    /// The brand colour; null keeps Ant's `#1677ff` seed primary.
    @ColorConverter() Color? accent,

    /// Whether dark surfaces collapse to true black.
    @Default(false) bool pureBlack,

    /// The layout density.
    @Default(UiDensity.comfortable) UiDensity density,

    /// A global font family override; null keeps the platform default.
    String? fontFamily,

    /// A multiplier on every font size — the global "enlarge text" control.
    @Default(1.0) double fontScale,

    /// A multiplier (0..1) on glass/scrim opacity; ignored when
    /// [reduceTransparency].
    @Default(1.0) double transparency,

    /// Accessibility: force surfaces opaque and disable backdrop blur.
    @Default(false) bool reduceTransparency,

    /// Whether motion runs.
    @Default(true) bool animations,

    /// Whether focused controls draw a visible outline.
    @Default(true) bool focusOutline,
  }) = _UiConfig;

  /// Rebuilds a configuration from its persisted JSON record.
  factory UiConfig.fromJson(Map<String, dynamic> json) => _$UiConfigFromJson(json);

  const UiConfig._();

  /// Builds the seed token this configuration implies.
  SeedToken toSeed() {
    final (sizeStep, controlHeight) = switch (density) {
      // Compact is a post-algorithm, so it needs no seed change here.
      UiDensity.compact || UiDensity.comfortable => (null, null),
      UiDensity.spacious => (5.0, 40.0),
    };
    return const SeedToken().copyWith(
      colorPrimary: accent,
      fontFamily: fontFamily,
      motion: animations,
      pureBlack: pureBlack,
      focusOutline: focusOutline,
      sizeStep: sizeStep,
      controlHeight: controlHeight,
    );
  }

  /// The algorithms to run, ordered like Ant's `[themeAlgorithm, compactAlgorithm]`.
  List<ThemeAlgorithm> algorithms({required bool dark}) {
    final list = <ThemeAlgorithm>[if (dark) ThemeAlgorithms.darkAlgorithm else ThemeAlgorithms.defaultAlgorithm];
    if (density == UiDensity.compact) {
      list.add(ThemeAlgorithms.compactAlgorithm);
    }
    return list;
  }

  /// Whether the resolved brightness is dark, given the platform setting.
  bool useDark({required bool platformDark}) => switch (brightness) {
    UiBrightnessMode.system => platformDark,
    UiBrightnessMode.light => false,
    UiBrightnessMode.dark => true,
  };

  /// The effective transparency multiplier (forced opaque when
  /// [reduceTransparency]).
  double get effectiveTransparency => reduceTransparency ? 0 : transparency.clamp(0.0, 1.0);

  /// Whether a backdrop filter may be drawn at all.
  bool get allowsTransparency => !reduceTransparency && effectiveTransparency > 0;
}
