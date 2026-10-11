import 'package:flutter/material.dart';

import 'package:live_uikit/src/core/ui_configuration.dart';
import 'package:live_uikit/src/core/ui_environment.dart';
import 'package:live_uikit/src/theme/live_color_scheme.dart';
import 'package:live_uikit/src/theme/live_component_theme.dart';
import 'package:live_uikit/src/theme/live_theme_data.dart';
import 'package:live_uikit/src/tokens/colors.dart';
import 'package:live_uikit/src/tokens/focus_tokens.dart';
import 'package:live_uikit/src/tokens/typography.dart';

/// Everything a design language is handed when it builds its theme.
///
/// The base parts are already resolved — an accent-derived palette, the
/// text scale, the density geometry and the focus tokens — so a language
/// refines what it cares about (radii, families, shadows, fills) and
/// inherits the rest instead of rebuilding a colour system from scratch.
/// That is also why the fields are values, not callbacks: a language that
/// throws cannot half-apply a theme.
@immutable
final class LiveDesignLanguageContext {
  /// The context a language builds from.
  const new({required this.configuration, required this.environment, required this.brightness, required this.base});

  /// The application's UI choices.
  final LiveUiConfiguration configuration;

  /// Where the UI runs (platform, layout, inputs, capacities).
  final LiveUiEnvironment environment;

  /// The brightness being rendered, already resolved from the policy.
  final Brightness brightness;

  /// The accent-derived parts to refine.
  final LiveThemeParts base;

  /// The light or dark variant of a colour, for languages that pick their
  /// own surfaces.
  bool get isDark => brightness == Brightness.dark;
}

/// The four token sets plus the Material theme of one design language.
@immutable
final class LiveThemeParts {
  /// A set of parts.
  const new({
    required this.colors,
    required this.typography,
    required this.componentTheme,
    required this.focus,
    required this.materialTheme,
  });

  /// The neutral base parts of [configuration] in [environment].
  ///
  /// "Neutral" means accent-derived, not Material-flavoured: Flutter's
  /// colour utilities derive the palette, the density table supplies the
  /// geometry and the focus tokens follow the layout mode. The Material
  /// design language is then the thinnest possible refinement of this base
  /// — which is the point: six languages cannot drift apart if five of
  /// them start from the same resolved values.
  // The `new.base(...)` shorthand does not parse on the current SDK, so the
  // type name stays.
  // ignore: unnecessary_type_name_in_constructor
  factory LiveThemeParts.base({
    required LiveUiConfiguration configuration,
    required LiveUiEnvironment environment,
    required Brightness brightness,
  }) {
    final accent = configuration.accentColor == null ? null : Color(configuration.accentColor!);
    final scheme = LiveColorScheme.material(brightness: brightness, accent: accent, pureBlack: configuration.pureBlack);
    final colors = LiveColorScheme.tokens(scheme, pureBlack: configuration.pureBlack);
    final typography = LiveTypography.standard().scaled(configuration.textScale);
    final componentTheme = LiveComponentTheme.forEnvironment(configuration.effectiveDensity(environment), environment);
    final focus = environment.layoutMode == LiveLayoutMode.tv ? LiveFocusTokens.tv : LiveFocusTokens.pointer;
    return LiveThemeParts(
      colors: colors,
      typography: typography,
      componentTheme: componentTheme,
      focus: configuration.enableFocusEffects ? focus : focus.copyWith(showRing: false, scale: 1),
      materialTheme: LiveThemeData.of(
        colors: colors,
        typography: typography,
        componentTheme: componentTheme,
        brightness: brightness,
      ),
    );
  }

  /// The semantic palette.
  final LiveColorTokens colors;

  /// The text roles.
  final LiveTypography typography;

  /// The component geometry.
  final LiveComponentTheme componentTheme;

  /// The focus appearance.
  final LiveFocusTokens focus;

  /// The Material theme left underneath the language's own components.
  final ThemeData materialTheme;

  /// The parts with some token sets replaced.
  ///
  /// The Material theme is rebuilt from the new values, so a language can
  /// only ever publish parts that agree with each other.
  LiveThemeParts withParts({
    LiveColorTokens? colors,
    LiveTypography? typography,
    LiveComponentTheme? componentTheme,
    LiveFocusTokens? focus,
    Brightness? brightness,
  }) {
    final nextColors = colors ?? this.colors;
    final nextTypography = typography ?? this.typography;
    final nextComponentTheme = componentTheme ?? this.componentTheme;
    return LiveThemeParts(
      colors: nextColors,
      typography: nextTypography,
      componentTheme: nextComponentTheme,
      focus: focus ?? this.focus,
      materialTheme: LiveThemeData.of(
        colors: nextColors,
        typography: nextTypography,
        componentTheme: nextComponentTheme,
        brightness: brightness ?? materialTheme.brightness,
      ),
    );
  }
}
