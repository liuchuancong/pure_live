// Module: lib/src/tokens_theme.dart
// Purpose: Carries the resolved design tokens and the role-to-colour mapping through the widget tree.
// Author: liuchuancong
// Created: 2026-10-10
//
// Spec: docs/architecture/pure_live_v2_flutter_technology_stack.md section 5.4 - every style adapter maps one
// set of semantic tokens, so a feature never writes Material constants on one screen and Fluent constants on
// another. ThemeData has slots for some of them (density, control heights, corners) and none for the three
// that matter most on a TV: which input the user is actually pointing with, how thick a focus ring has to be
// to be seen at three metres, and whether anything is allowed to animate at all. This extension is the slot
// for those.
//
// Two choices are deliberate. Colour roles resolve here rather than in the token package, because a role is
// a name and only a scheme has values - pure Dart design tokens stay numbers. And a widget that reads these
// tokens outside a themed tree falls back to the platform's default instead of throwing: a missing extension
// would otherwise take down a route for what is, in the fallback case, a slightly different spacing number.

import 'package:flutter/material.dart';

import 'package:pure_live_design/pure_live_design.dart';

/// The token set plus the role mapping a style adapter chose, as one [ThemeExtension].
@immutable
final class DesignTokensTheme extends ThemeExtension<DesignTokensTheme> {
  const DesignTokensTheme({required this.tokens, required this.roles});

  final DesignTokens tokens;

  /// What each semantic role looks like in the active style. A style may leave a role unmapped; a widget that
  /// asks for it has to have its own fallback, because "the style did not say" is not a colour.
  final Map<ColorRole, Color> roles;

  /// The tokens for the tree, with the platform's own defaults when nothing installed them (a bare widget
  /// test, a plugin's dialog, a route built above the app theme).
  factory DesignTokensTheme.forPlatform(TargetPlatform platform, ColorScheme scheme) => DesignTokensTheme(
    tokens: resolveDesignTokens(platform: platformProfileOf(platform)),
    roles: rolesOfScheme(scheme),
  );

  InputMode get input => tokens.input;

  Density get density => tokens.density;

  MotionProfile get motion => tokens.motion;

  FocusVisual get focus => tokens.focus;

  /// The height a control of [kind] has to take in this tree.
  double height(ControlKind kind) => tokens.height(kind);

  /// The gap that belongs between two controls of [kind].
  double gap(ControlKind kind) => tokens.gapBetween(kind);

  /// The size of a type role, with the remote-readable floor already applied.
  double typeSize(TypeRole role) => tokens.typeSize(role);

  /// A duration by role. Reduced motion arrives here as [Duration.zero], which means "swap without
  /// animating" - not "animate faster", the thing the setting is asking relief from.
  Duration duration(MotionSize size) => switch (size) {
    MotionSize.instant => motion.instant,
    MotionSize.quick => motion.quick,
    MotionSize.standard => motion.standard,
    MotionSize.slow => motion.slow,
  };

  /// The colour a role resolves to, or null when the active style did not map it.
  Color? color(ColorRole role) => roles[role];

  /// The ring side a focused control draws, or null when the style expresses focus as its own outline.
  ///
  /// Null is a real answer, not a missing one: layering a ring over an outline doubles the visual weight at
  /// exactly the states that already read as focused.
  BorderSide? focusRing(Color color) => focus.shape == FocusShape.outline
      ? null
      : BorderSide(color: color, width: focus.width);

  @override
  DesignTokensTheme copyWith({DesignTokens? tokens, Map<ColorRole, Color>? roles}) => DesignTokensTheme(
    tokens: tokens ?? this.tokens,
    roles: roles ?? this.roles,
  );

  @override
  DesignTokensTheme lerp(covariant ThemeExtension<DesignTokensTheme>? other, double t) {
    // Configuration, not an animatable value: a theme change swaps the set at the end rather than blending
    // two densities into a third that nobody chose.
    if (other is! DesignTokensTheme) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}

/// The durations a caller asks for by role, so no component writes a millisecond literal.
enum MotionSize { instant, quick, standard, slow }

/// Reading the tokens back out.
extension DesignTokensReader on BuildContext {
  /// The active tokens, or the platform default when a tree was built without them.
  DesignTokens get designTokens => themeTokens.tokens;

  /// The full extension, for callers that need the role colours as well.
  DesignTokensTheme get themeTokens {
    final theme = Theme.of(this);
    return theme.extension<DesignTokensTheme>() ?? DesignTokensTheme.forPlatform(theme.platform, theme.colorScheme);
  }
}

/// The Flutter platform family translated into the profile the tokens are keyed by.
///
/// Android TV reports as android, so a host that knows it is on a TV has to say so when it resolves the
/// tokens - inferring it from a screen width would make a tablet in a car mount a ten-foot interface.
PlatformProfile platformProfileOf(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => PlatformProfile.androidPhone,
  TargetPlatform.iOS => PlatformProfile.ios,
  TargetPlatform.windows => PlatformProfile.windows,
  TargetPlatform.macOS => PlatformProfile.macos,
  TargetPlatform.linux => PlatformProfile.linux,
  TargetPlatform.fuchsia => PlatformProfile.androidPhone,
};

/// The inverse: the platform a style asks Flutter to render controls as.
TargetPlatform targetPlatformFor(PlatformProfile profile) => switch (profile) {
  PlatformProfile.androidPhone || PlatformProfile.androidTv => TargetPlatform.android,
  PlatformProfile.ios => TargetPlatform.iOS,
  PlatformProfile.windows => TargetPlatform.windows,
  PlatformProfile.macos => TargetPlatform.macOS,
  PlatformProfile.linux => TargetPlatform.linux,
};

/// The default role mapping: Material 3's scheme slots translated to this project's vocabulary.
///
/// A style adapter that wants a different reading of, say, [ColorRole.selection] overrides the entry rather
/// than replacing the map, so adding a role here does not silently disappear in every style.
Map<ColorRole, Color> rolesOfScheme(ColorScheme scheme) => <ColorRole, Color>{
  ColorRole.surface: scheme.surface,
  ColorRole.surfaceVariant: scheme.surfaceContainerHighest,
  ColorRole.primary: scheme.primary,
  ColorRole.onPrimary: scheme.onPrimary,
  ColorRole.onSurface: scheme.onSurface,
  ColorRole.onSurfaceVariant: scheme.onSurfaceVariant,
  ColorRole.error: scheme.error,
  ColorRole.outline: scheme.outline,
  ColorRole.outlineVariant: scheme.outlineVariant,
  ColorRole.selection: scheme.secondaryContainer,
  ColorRole.focus: scheme.tertiary,
  ColorRole.scrim: scheme.scrim,
  ColorRole.overlayText: Colors.white,
};
