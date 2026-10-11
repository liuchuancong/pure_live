import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/core/ui_component_registry.dart';
import 'package:live_uikit/src/design_languages/cupertino/cupertino_components.dart';
import 'package:live_uikit/src/theme/live_theme_parts.dart';
import 'package:live_uikit/src/tokens/radii.dart';

/// The Cupertino design language.
///
/// The refinement is geometry and type rather than colour: iOS corners are
/// rounder than Material's on controls and tighter on cards, fields are
/// shorter, and the type scale is the system one (San Francisco through the
/// platform's default family). The palette stays the accent-derived one so
/// that a user's chosen accent survives the switch, which is what iOS apps
/// themselves do with their tint colour.
///
/// The language styles every control explicitly instead of installing a
/// [CupertinoThemeData]: a Cupertino control that reads its colour from an
/// inherited theme would silently fall back to the system blue the moment
/// one of them is built outside the app's theme scope, and a screen with
/// two different blues is worse than a screen with none.
abstract final class CupertinoLanguage {
  /// The language's component implementation.
  static const CupertinoComponents components = CupertinoComponents();

  /// The language's adapter, for the registry.
  static const LiveDesignLanguageAdapter adapter = LiveDesignLanguageAdapter(
    theme: _buildTheme,
    components: components,
  );

  static LiveThemeParts _buildTheme(LiveDesignLanguageContext context) {
    final base = context.base;
    final density = base.componentTheme;
    final geometry = density.copyWith(
      controlRadius: LiveRadii.sm,
      cardRadius: 10,
      cardElevation: 0,
      dialogRadius: 14,
      menuRadius: 14,
      inputRadius: LiveRadii.sm,
      // iOS fields are shorter than Material's at the same density, but not
      // so short that the text loses its line height.
      inputHeight: math.max(32, density.inputHeight - 4),
      cardPadding: const EdgeInsets.all(12),
      cardPaddingDense: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
    return base.withParts(
      componentTheme: geometry,
      focus: base.focus.copyWith(ringRadius: geometry.controlRadius, scale: 1),
    );
  }
}
