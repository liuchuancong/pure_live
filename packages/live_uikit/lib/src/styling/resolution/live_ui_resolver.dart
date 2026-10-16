import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/diagnostics/diagnostics.dart';
import 'package:live_uikit/src/styling/resolution/live_ui_fallback_policy.dart';
import 'package:live_uikit/src/styling/resolution/live_ui_registry.dart';

/// The outcome of resolving one language: which [adapter] renders it and how
/// ([kind]) (§15.1). Read by rendering, tests and diagnostics alike.
final class LiveResolvedImplementation {
  /// A resolution to [adapter] rendered as [kind].
  const new({required this.adapter, required this.kind});

  /// The adapter that will draw the controls.
  final LanguageAdapter adapter;

  /// Whether it is a native adapter, the shared fallback or a custom override.
  final LiveImplementationKind kind;
}

/// A resolution plus the diagnostic explaining a downgrade, or `null` when the
/// language was served natively (§15.5: every downgrade is observable).
final class LiveUiResolution {
  /// A resolution of [implementation], optionally reporting [diagnostic].
  const new({required this.implementation, this.diagnostic});

  /// The chosen adapter and kind.
  final LiveResolvedImplementation implementation;

  /// Why the control did not resolve natively, or null when it did.
  final LiveUiDiagnostic? diagnostic;
}

/// Thrown when the [LiveUiFallbackPolicy] demands a fail-fast on a gap that
/// leaves nothing to render — a startup-level fault, never a silent blank (§7).
final class LiveUiResolutionException implements Exception {
  /// An exception describing an unresolvable [language].
  const new(this.language);

  /// The language that could not be served.
  final LiveDesignLanguage language;

  @override
  String toString() =>
      'LiveUiResolutionException: no implementation available for $language '
      'and the fallback policy is fail-fast (§7/§15.4).';
}

/// The single place that decides which adapter renders a language (§15.3).
///
/// Public controls never inspect the design language themselves; the
/// `LiveConfigProvider` resolves once through here, and the returned
/// [LiveResolvedImplementation] carries the [LiveImplementationKind] so the
/// dispatch is assertable. The resolver is side-effect-free — it *returns* a
/// [LiveUiResolution] (implementation plus any diagnostic) rather than logging,
/// keeping the decision pure and testable (§15.6).
final class LiveUiResolver {
  /// A resolver over [registry] applying [policy].
  const new({required this.registry, this.policy = const LiveUiFallbackPolicy()});

  /// The registered adapters and the shared fallback.
  final LanguageRegistry registry;

  /// The downgrade rules to apply on a gap.
  final LiveUiFallbackPolicy policy;

  /// Resolves [language] to an adapter and kind, recording any downgrade.
  LiveUiResolution resolve(LiveDesignLanguage language) {
    final adapter = registry.adapters[language];
    if (adapter != null) {
      return LiveUiResolution(
        implementation: LiveResolvedImplementation(adapter: adapter, kind: LiveImplementationKind.adapterNative),
      );
    }
    // No dedicated adapter (§15.3 step 2a). The shared fallback still renders
    // on-theme, so the usual policy records the downgrade and serves shared.
    final shared = LiveResolvedImplementation(adapter: registry.fallback, kind: LiveImplementationKind.shared);
    if (policy.onMissingAdapter == LiveUiFallbackAction.failFast) {
      throw LiveUiResolutionException(language);
    }
    return LiveUiResolution(
      implementation: shared,
      diagnostic: LiveUiDiagnostic(code: LiveUiDiagnosticCode.adapterMissing, language: language, kind: shared.kind),
    );
  }

  /// Resolves one [control] for [language], recording a `controlUnsupported`
  /// downgrade when the registered adapter does not render it natively (§15.3).
  ///
  /// A language-wide gap already yields an `adapterMissing` resolution; when the
  /// adapter is present but lacks just this control, the shared token renderer
  /// stands in — the *same* adapter instance, whose un-overridden method defers
  /// to it — so the kind is [LiveImplementationKind.shared], never a silent lie.
  LiveUiResolution resolveControl(LiveDesignLanguage language, LiveUiControl control) {
    final resolution = resolve(language);
    final adapter = resolution.implementation.adapter;
    if (resolution.diagnostic != null || adapter.capabilities.supports(control)) {
      return resolution;
    }
    if (policy.onUnsupportedControl == LiveUiFallbackAction.failFast) {
      throw LiveUiResolutionException(language);
    }
    return LiveUiResolution(
      implementation: LiveResolvedImplementation(adapter: adapter, kind: LiveImplementationKind.shared),
      diagnostic: LiveUiDiagnostic(code: LiveUiDiagnosticCode.controlUnsupported, language: language, control: control),
    );
  }
}
