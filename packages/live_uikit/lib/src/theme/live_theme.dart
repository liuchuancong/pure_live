import 'package:flutter/material.dart';

import 'package:live_uikit/src/components/contracts/live_design_language_components.dart';
import 'package:live_uikit/src/core/design_language.dart';
import 'package:live_uikit/src/core/ui_configuration.dart';
import 'package:live_uikit/src/core/ui_environment.dart';
import 'package:live_uikit/src/theme/live_component_theme.dart';
import 'package:live_uikit/src/theme/live_theme_parts.dart';
import 'package:live_uikit/src/tokens/colors.dart';
import 'package:live_uikit/src/tokens/focus_tokens.dart';
import 'package:live_uikit/src/tokens/motion.dart';
import 'package:live_uikit/src/tokens/typography.dart';

/// A resolved theme: the tokens, the components and the Material theme the
/// current configuration and environment produce.
///
/// Pages read it from the tree (`LiveTheme.of(context)`) and use its
/// tokens and its `components` implementation. The Material theme rides
/// along for the Flutter widgets that need one; it is not the API a page
/// should reach for.
@immutable
final class LiveTheme {
  /// A resolved theme.
  const new({
    required this.configuration,
    required this.environment,
    required this.requestedLanguage,
    required this.designLanguage,
    required this.brightness,
    required this.parts,
    required this.components,
    this.fallbacks = const [],
  });

  /// The choices this theme was resolved from.
  final LiveUiConfiguration configuration;

  /// The environment it was resolved for.
  final LiveUiEnvironment environment;

  /// The design language the configuration asked for.
  final LiveDesignLanguage requestedLanguage;

  /// The design language actually rendering — [requestedLanguage] unless it
  /// was unregistered, in which case this is the fallback.
  final LiveDesignLanguage designLanguage;

  /// The brightness being rendered.
  final Brightness brightness;

  /// The token sets of [designLanguage].
  final LiveThemeParts parts;

  /// The component implementation of [designLanguage].
  final LiveDesignLanguageComponents components;

  /// Notes about every substitution made while resolving, for logging and
  /// the diagnostics page; empty when the theme is exactly what was asked
  /// for.
  final List<String> fallbacks;

  /// Whether the rendered language differs from the requested one.
  bool get usedFallback => designLanguage != requestedLanguage;

  /// The semantic palette.
  LiveColorTokens get colors => parts.colors;

  /// The text roles.
  LiveTypography get typography => parts.typography;

  /// The component geometry.
  LiveComponentTheme get componentTheme => parts.componentTheme;

  /// The focus appearance.
  LiveFocusTokens get focus => parts.focus;

  /// The Material theme for any Material widget that lands in the tree.
  ThemeData get materialTheme => parts.materialTheme;

  /// Whether animations may run.
  bool get animationsEnabled => configuration.enableAnimations;

  /// The hover/press/focus feedback duration, [LiveMotion.instant] when
  /// animations are off — the one place reduced motion is applied.
  Duration get fast => animationsEnabled ? LiveMotion.fast : LiveMotion.instant;

  /// The default transition duration.
  Duration get normal => animationsEnabled ? LiveMotion.normal : LiveMotion.instant;

  /// The page transition duration.
  Duration get slow => animationsEnabled ? LiveMotion.slow : LiveMotion.instant;

  /// The hero-like transition duration.
  Duration get slower => animationsEnabled ? LiveMotion.slower : LiveMotion.instant;

  /// The theme of the nearest [LiveThemeScope], or null outside one.
  static LiveTheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiveThemeScope>()?.theme;

  /// The theme of the nearest [LiveThemeScope].
  ///
  /// Throws when there is none: a page built outside the app's theme scope
  /// has no tokens to read, and inventing defaults would hide a wiring bug
  /// behind plausible colours. Widgets written for previews should take a
  /// `LiveTheme` parameter instead of reaching into the tree.
  static LiveTheme of(BuildContext context) {
    final theme = maybeOf(context);
    if (theme == null) {
      throw FlutterError.fromParts([
        ErrorSummary('No LiveThemeScope found above this widget.'),
        ErrorDescription(
          'live_uikit components read their tokens from a LiveThemeScope. '
          'The application wraps its MaterialApp (or its router) in one; a '
          'widget tested or previewed in isolation must be given one too.',
        ),
      ]);
    }
    return theme;
  }

  /// The same theme with some fields replaced, for the resolver and for
  /// previews that need to tweak one part.
  LiveTheme copyWith({
    LiveUiConfiguration? configuration,
    LiveUiEnvironment? environment,
    LiveDesignLanguage? requestedLanguage,
    LiveDesignLanguage? designLanguage,
    Brightness? brightness,
    LiveThemeParts? parts,
    LiveDesignLanguageComponents? components,
    List<String>? fallbacks,
  }) => LiveTheme(
    configuration: configuration ?? this.configuration,
    environment: environment ?? this.environment,
    requestedLanguage: requestedLanguage ?? this.requestedLanguage,
    designLanguage: designLanguage ?? this.designLanguage,
    brightness: brightness ?? this.brightness,
    parts: parts ?? this.parts,
    components: components ?? this.components,
    fallbacks: fallbacks ?? this.fallbacks,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LiveTheme &&
        other.configuration == configuration &&
        other.environment == environment &&
        other.requestedLanguage == requestedLanguage &&
        other.designLanguage == designLanguage &&
        other.brightness == brightness &&
        other.colors == colors &&
        other.typography == typography &&
        other.componentTheme == componentTheme &&
        other.focus == focus &&
        identical(other.components, components);
  }

  @override
  int get hashCode => Object.hash(
    configuration,
    environment,
    requestedLanguage,
    designLanguage,
    brightness,
    colors,
    typography,
    componentTheme,
    focus,
    identityHashCode(components),
  );
}

/// Provides a [LiveTheme] to the tree.
///
/// Installed once by the application, above everything that renders — and
/// re-installed (not re-created) when the design language, the brightness
/// or the window size changes, so business state underneath it survives a
/// theme switch untouched.
class LiveThemeScope extends InheritedWidget {
  /// A scope providing [theme].
  const new({required this.theme, required super.child, super.key});

  /// The theme every `LiveTheme.of(context)` below this widget returns.
  final LiveTheme theme;

  @override
  bool updateShouldNotify(LiveThemeScope oldWidget) => theme != oldWidget.theme;
}
