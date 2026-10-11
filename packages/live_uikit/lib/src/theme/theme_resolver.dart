import 'package:live_uikit/src/core/ui_component_registry.dart';
import 'package:live_uikit/src/core/ui_configuration.dart';
import 'package:live_uikit/src/core/ui_environment.dart';
import 'package:live_uikit/src/theme/live_theme.dart';
import 'package:live_uikit/src/theme/live_theme_parts.dart';

/// Turns a configuration and an environment into a [LiveTheme].
///
/// The resolver is the only place that decides *which* language renders:
/// the configuration asks for one, the registry says whether it is there,
/// and an unregistered language resolves to the fallback with a note in
/// [LiveTheme.fallbacks] instead of a silent substitution. Resolved themes
/// are cached by their inputs, so a rebuild — a window resize, a provider
/// update, a page transition — returns the same instance and does not churn
/// the tree.
final class LiveThemeResolver {
  /// A resolver over [registry].
  ///
  /// [onFallback] receives every substitution note once, for start-up
  /// logging: the resolver itself stays free of logging so it can run
  /// inside a build phase.
  new(this.registry, {this.onFallback, this.cacheSize = 8});

  /// The languages the app can render.
  final LiveComponentRegistry registry;

  /// Reports each substitution note the first time it happens.
  final void Function(String note)? onFallback;

  /// How many resolved themes are kept, most recent first.
  final int cacheSize;
  final List<(LiveUiConfiguration, LiveUiEnvironment, bool, LiveTheme)> _cache = [];

  /// Resolves the theme for [configuration] in [environment].
  ///
  /// [platformDark] is the platform's current brightness, which only
  /// matters when the configuration follows the system.
  LiveTheme resolve({
    required LiveUiConfiguration configuration,
    required LiveUiEnvironment environment,
    required bool platformDark,
  }) {
    for (final (cachedConfiguration, cachedEnvironment, cachedDark, theme) in _cache) {
      if (cachedConfiguration == configuration && cachedEnvironment == environment && cachedDark == platformDark) {
        return theme;
      }
    }
    final theme = _resolve(configuration: configuration, environment: environment, platformDark: platformDark);
    _cache.insert(0, (configuration, environment, platformDark, theme));
    if (_cache.length > cacheSize) {
      _cache.removeLast();
    }
    return theme;
  }

  /// The theme of the fallback language, for previews and for the window
  /// shown before the user's settings have loaded.
  LiveTheme resolveFallback({
    required LiveUiEnvironment environment,
    required bool platformDark,
    LiveUiConfiguration? configuration,
  }) => resolve(
    configuration: (configuration ?? const LiveUiConfiguration()).copyWith(designLanguage: registry.fallback),
    environment: environment,
    platformDark: platformDark,
  );

  LiveTheme _resolve({
    required LiveUiConfiguration configuration,
    required LiveUiEnvironment environment,
    required bool platformDark,
  }) {
    final brightness = configuration.resolveBrightness(platformDark: platformDark);
    final requested = configuration.designLanguage;
    final fallbacks = <String>[];
    var rendered = requested;
    if (!registry.isRegistered(requested)) {
      rendered = registry.fallback;
      fallbacks.add(
        'design language "${requested.id}" is not registered; '
        'rendering "${rendered.id}" instead',
      );
    }
    final report = onFallback;
    if (report != null && fallbacks.isNotEmpty) {
      fallbacks.forEach(report);
    }
    final adapter = registry.adapterFor(rendered);
    final base = LiveThemeParts.base(configuration: configuration, environment: environment, brightness: brightness);
    final parts = adapter.theme(
      LiveDesignLanguageContext(
        configuration: configuration,
        environment: environment,
        brightness: brightness,
        base: base,
      ),
    );
    return LiveTheme(
      configuration: configuration,
      environment: environment,
      requestedLanguage: requested,
      designLanguage: rendered,
      brightness: brightness,
      parts: parts,
      components: adapter.components,
      fallbacks: List.unmodifiable(fallbacks),
    );
  }
}
