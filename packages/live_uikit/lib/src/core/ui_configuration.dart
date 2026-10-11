import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:live_uikit/src/core/design_language.dart';
import 'package:live_uikit/src/core/ui_environment.dart';
import 'package:live_uikit/src/tokens/breakpoints.dart';

part 'ui_configuration.freezed.dart';

/// How tightly components are packed.
///
/// Density is a user-visible preference (and a TV necessity), separate from
/// both the design language and the layout mode: Material on a phone is
/// comfortable, the same Material on a desktop with a mouse may be compact,
/// and a TV is always spacious.
enum LiveUiDensity {
  /// Desktop with a pointer: shorter controls, tighter padding.
  compact,

  /// Phones and default desktop: the shipping default.
  comfortable,

  /// Large screens and long viewing distances: taller controls, more air.
  spacious;

  /// The density a layout mode defaults to.
  static LiveUiDensity forLayoutMode(LiveLayoutMode mode) => switch (mode) {
    LiveLayoutMode.mobile => LiveUiDensity.comfortable,
    LiveLayoutMode.desktop => LiveUiDensity.compact,
    LiveLayoutMode.tv => LiveUiDensity.spacious,
  };
}

/// Which brightness the UI renders in.
///
/// Mirrors the stored preference so the UI layer never depends on the
/// preferences package; the composition root maps one to the other.
enum LiveBrightness {
  /// Follow the platform's current setting.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark;

  /// The concrete brightness, resolving [system] through [platformDark].
  Brightness resolve({required bool platformDark}) => switch (this) {
    LiveBrightness.system => platformDark ? Brightness.dark : Brightness.light,
    LiveBrightness.light => Brightness.light,
    LiveBrightness.dark => Brightness.dark,
  };
}

/// The UI configuration: every *choice* the theme resolver needs, gathered
/// in one immutable value by the composition root.
///
/// Choices only — the design language, the brightness policy, the accent,
/// the density, and the animation and focus switches. The facts about where
/// the UI runs (platform, layout mode, input devices, whether blur is
/// affordable) live in [LiveUiEnvironment], and the resolver takes both:
/// keeping them apart is what lets the same configuration render on a phone
/// and on a TV without either side guessing about the other.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class LiveUiConfiguration with _$LiveUiConfiguration {
  /// A configuration; [density] defaults to what the layout mode implies.
  const factory LiveUiConfiguration({
    /// The active design language.
    @Default(LiveDesignLanguage.material) LiveDesignLanguage designLanguage,

    /// The component density, or null for the layout mode's default.
    LiveUiDensity? density,

    /// The colour scheme's brightness policy.
    @Default(LiveBrightness.system) LiveBrightness brightness,

    /// The user's accent colour as 32-bit ARGB; null uses the design
    /// language's own accent.
    int? accentColor,

    /// Whether dark surfaces are drawn pure black (OLED).
    @Default(false) bool pureBlack,

    /// Whether transitions, focus animations and ripples may run.
    @Default(true) bool enableAnimations,

    /// Whether focus rings and focus growth are drawn.
    @Default(true) bool enableFocusEffects,

    /// A scale applied to every font size, for TV builds and the user's
    /// text-size preference; 1 is the design language's own scale.
    @Default(1) double textScale,

    /// The window-size-class thresholds in force.
    @Default(LiveBreakpoints()) LiveBreakpoints breakpoints,
  }) = _LiveUiConfiguration;

  /// The configuration's density, defaulting from [environment]'s layout.
  static LiveUiDensity densityOf(LiveUiConfiguration configuration, LiveUiEnvironment environment) =>
      configuration.density ?? LiveUiDensity.forLayoutMode(environment.layoutMode);
}

/// The configuration's derived values.
extension LiveUiConfigurationX on LiveUiConfiguration {
  /// The effective density under [environment].
  LiveUiDensity effectiveDensity(LiveUiEnvironment environment) => LiveUiConfiguration.densityOf(this, environment);

  /// The brightness to render, resolving [LiveBrightness.system] against
  /// the platform's current setting.
  Brightness resolveBrightness({required bool platformDark}) => brightness.resolve(platformDark: platformDark);
}
