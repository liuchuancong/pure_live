import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/contracts/live_ui_surfaces.dart';
import 'package:live_uikit/src/styling/diagnostics/diagnostics.dart';
import 'package:live_uikit/src/styling/resolution/live_ui_registry.dart';

/// Thrown when a language has no adapter in this build (§7/§15.4).
///
/// This is a startup-level fault, not a degraded render: there is no shared
/// renderer left to stand in, so the alternative to throwing is a window painted
/// by a library the user did not choose. The composition root registers every
/// language it claims to support; anything else is a bug it should hear about.
final class LiveUiResolutionException implements Exception {
  /// An exception describing an unresolvable [language].
  const new(this.language);

  /// The language that could not be served.
  final LiveDesignLanguage language;

  @override
  String toString() => 'LiveUiResolutionException: no adapter is registered for $language (§7/§15.4).';
}

/// Thrown when an adapter claims a capability it cannot serve — a declaration
/// that has drifted from the methods the adapter actually overrides (§17).
final class LiveUiCapabilityException implements Exception {
  /// An exception for [language] failing to render [control] or own [surface].
  const new(this.language, {this.control, this.surface});

  /// The language whose adapter was asked.
  final LiveDesignLanguage language;

  /// The control that was not rendered, for a control failure.
  final LiveUiControl? control;

  /// The surface that was not owned, for a structural failure.
  final LiveUiSurface? surface;

  @override
  String toString() =>
      'LiveUiCapabilityException: $language does not serve '
      '${control?.name ?? surface?.name} although it declares it (§17).';
}

/// The single place that decides which adapter renders a language (§15.3).
///
/// Public controls never inspect the design language themselves; the
/// `LiveConfigProvider` resolves once through here. There is no downgrade to
/// report any more — either the build registered an adapter for the language or
/// it fails loudly — so the resolver returns the adapter itself.
final class LiveUiResolver {
  /// A resolver over [registry].
  const new({required this.registry});

  /// The registered adapters.
  final LanguageRegistry registry;

  /// The adapter that renders [language].
  ///
  /// Throws [LiveUiResolutionException] when this build registered none.
  LanguageAdapter resolve(LiveDesignLanguage language) {
    final adapter = registry.adapterFor(language);
    if (adapter == null) {
      throw LiveUiResolutionException(language);
    }
    return adapter;
  }

  /// Checks that [language]'s adapter really serves [control] — the assertion
  /// behind a capability declaration, used by the test suites (§17).
  void requireControl(LiveDesignLanguage language, LiveUiControl control) {
    if (!resolve(language).capabilities.supports(control)) {
      throw LiveUiCapabilityException(language, control: control);
    }
  }

  /// Checks that [language]'s adapter really owns [surface] (§17).
  void requireSurface(LiveDesignLanguage language, LiveUiSurface surface) {
    if (!resolve(language).surfaces.supports(surface)) {
      throw LiveUiCapabilityException(language, surface: surface);
    }
  }
}
