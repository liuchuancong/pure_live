import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/backgrounds/background_style.dart';
import 'package:live_uikit/src/core/ui_environment.dart';
import 'package:live_uikit/src/tokens/colors.dart';

/// The backgrounds the app's surfaces use.
///
/// Presets keep policy in one place. Two rules matter most:
/// a preset never returns a backdrop blur the environment cannot afford
/// (TV builds and low-end devices get a flat or translucent fill instead),
/// and every scrim strength is expressed here rather than in a page, so
/// text contrast is a theme decision.
abstract final class LiveBackgroundPresets {
  /// The page background: a very subtle gradient from the surface towards
  /// the accent, or a flat surface in a reduced-effects environment.
  static LiveBackgroundStyle page(
    LiveColorTokens colors, {
    LiveUiEnvironment? environment,
    Color? accent,
    bool plain = false,
  }) {
    final tint = accent ?? colors.primary;
    final dark = colors.surface.computeLuminance() < 0.5;
    if (plain || (environment != null && !environment.supportsBlur)) {
      return LiveBackgroundStyle.solid(color: colors.surface);
    }
    return LiveBackgroundStyle.gradient(
      colors: [colors.surface, Color.lerp(colors.surface, tint, dark ? 0.14 : 0.08) ?? colors.surface],
      begin: const Alignment(-0.6, -1),
      end: const Alignment(0.6, 1),
    );
  }

  /// The TV page background: larger, calmer steps than the phone one,
  /// because a gradient that reads as subtle on a phone reads as a hard
  /// edge three metres away.
  static LiveBackgroundStyle tv(LiveColorTokens colors, {Color? accent}) {
    final tint = accent ?? colors.primary;
    final dark = colors.surface.computeLuminance() < 0.5;
    return LiveBackgroundStyle.gradient(
      colors: [colors.surface, Color.lerp(colors.surface, tint, dark ? 0.1 : 0.06) ?? colors.surface],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  /// A card surface: flat, because cards sit on the page background and a
  /// second gradient behind every tile reads as noise.
  static LiveBackgroundStyle card(LiveColorTokens colors, {bool elevated = false}) =>
      LiveBackgroundStyle.solid(color: elevated ? colors.surfaceElevated : colors.surfaceVariant);

  /// A dialog surface: flat, in the elevated tone, so it separates from the
  /// scrimmed page in every design language.
  static LiveBackgroundStyle dialog(LiveColorTokens colors) => LiveBackgroundStyle.solid(color: colors.surfaceElevated);

  /// A frosted surface for control bars over video, when the environment
  /// can afford a backdrop filter; otherwise a translucent flat fill that
  /// keeps the same contrast.
  static LiveBackgroundStyle glass(LiveColorTokens colors, {LiveUiEnvironment? environment, double opacity = 0.62}) {
    final fill = colors.surfaceOverlay.withValues(alpha: opacity);
    if (environment != null && !environment.supportsBlur) {
      return LiveBackgroundStyle.solid(color: fill);
    }
    return LiveBackgroundStyle.glass(color: fill, sigma: 18, border: colors.divider.withValues(alpha: 0.3));
  }

  /// The scrim painted between a video frame and the UI over it.
  static LiveBackgroundStyle playerScrim(LiveColorTokens colors) => LiveBackgroundStyle.gradient(
    colors: [
      colors.scrim.withValues(alpha: 0.65),
      colors.scrim.withValues(alpha: 0),
      colors.scrim.withValues(alpha: 0.75),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// A soft-embossed surface, for the Neumorphic language and for raised
  /// cards in any language that wants the treatment.
  static LiveBackgroundStyle raised(LiveColorTokens colors, {double depth = 6}) => LiveBackgroundStyle.raised(
    base: colors.surfaceElevated,
    light: Color.alphaBlend(const Color(0xFFFFFFFF).withValues(alpha: 0.7), colors.surfaceElevated),
    dark: Color.alphaBlend(const Color(0xFF000000).withValues(alpha: 0.35), colors.surfaceElevated),
    depth: depth,
  );
}
