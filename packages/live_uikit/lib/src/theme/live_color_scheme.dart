import 'package:flutter/material.dart';

import 'package:live_uikit/src/tokens/colors.dart';

/// The colour machinery shared by every design language.
///
/// Flutter's Material colour utilities are used to *derive* a coherent
/// palette from one accent and one brightness — that is colour science, not
/// a design language — and each language then maps or overrides the result.
/// The semantic roles in [LiveColorTokens] are what pages see; a
/// `ColorScheme` never leaves this file's callers except as the Material
/// theme's own data.
abstract final class LiveColorScheme {
  /// Pure Live's brand blue, the accent when the user has not chosen one.
  static const Color brandAccent = Color(0xFF2E6FE0);

  /// Success green, tuned per brightness; Material's scheme has no success
  /// role, so the two semantic states live here.
  static const Color successLight = Color(0xFF2E7D32);

  /// Success green for dark surfaces.
  static const Color successDark = Color(0xFF6BCB77);

  /// Warning amber for light surfaces.
  static const Color warningLight = Color(0xFFB26A00);

  /// Warning amber for dark surfaces.
  static const Color warningDark = Color(0xFFFFB74D);

  /// A Material colour scheme from [accent] and [brightness].
  ///
  /// [pureBlack] flattens every dark surface to black, which OLED screens
  /// and TV panels show as genuinely off pixels.
  static ColorScheme material({required Brightness brightness, Color? accent, bool pureBlack = false}) {
    final scheme = ColorScheme.fromSeed(seedColor: accent ?? brandAccent, brightness: brightness);
    if (brightness != Brightness.dark || !pureBlack) {
      return scheme;
    }
    return scheme.copyWith(
      surface: const Color(0xFF000000),
      surfaceContainerLowest: const Color(0xFF000000),
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: const Color(0xFF111111),
      surfaceContainerHigh: const Color(0xFF171717),
      surfaceContainerHighest: const Color(0xFF1F1F1F),
    );
  }

  /// The semantic tokens of [scheme].
  static LiveColorTokens tokens(ColorScheme scheme, {bool pureBlack = false}) {
    final dark = scheme.brightness == Brightness.dark;
    final overlayBase = pureBlack ? const Color(0xFF000000) : scheme.surface;
    return LiveColorTokens(
      surface: scheme.surface,
      surfaceElevated: scheme.surfaceContainerHigh,
      surfaceVariant: scheme.surfaceContainerHighest,
      surfaceOverlay: overlayBase.withValues(alpha: 0.82),
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      secondary: scheme.secondary,
      outline: scheme.outline,
      divider: scheme.outlineVariant,
      error: scheme.error,
      onError: scheme.onError,
      success: dark ? successDark : successLight,
      warning: dark ? warningDark : warningLight,
      focus: scheme.tertiary,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      textDisabled: scheme.onSurface.withValues(alpha: 0.38),
      shadow: pureBlack ? const Color(0xFF000000) : scheme.shadow,
      scrim: scheme.scrim,
    );
  }
}
