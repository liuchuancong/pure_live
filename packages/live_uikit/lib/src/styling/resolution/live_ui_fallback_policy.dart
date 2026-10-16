import 'package:flutter/foundation.dart' show immutable;

/// What the runtime does when a control cannot be served by the active
/// language's native adapter (§15.4).
enum LiveUiFallbackAction {
  /// Stop with a diagnosable error — used only where continuing would render a
  /// silently broken UI (the default language has no fallback at all).
  failFast,

  /// Render the shared token implementation and record why (§15.3 step 2a/2b).
  fallbackToShared,
}

/// The downgrade rules the `LiveUiResolver` applies (§15.4).
///
/// The policy is *core* logic — it decides what happens on a gap — while the
/// implementations it falls back to live in the adapter/shared layers (§4). A
/// core must never downgrade in a way this policy has not declared (§8.10), so
/// each knob both picks the action and names the situation it governs.
@immutable
final class LiveUiFallbackPolicy {
  /// A policy; every knob defaults to the shipped behaviour unless overridden.
  const new({
    this.onMissingAdapter = LiveUiFallbackAction.fallbackToShared,
    this.onMissingDefaultAdapter = LiveUiFallbackAction.failFast,
    this.onUnsupportedControl = LiveUiFallbackAction.fallbackToShared,
    this.onUnsupportedSurface = LiveUiFallbackAction.fallbackToShared,
  });

  /// How to serve a language whose adapter is not registered.
  ///
  /// Defaults to [LiveUiFallbackAction.fallbackToShared]: the shared renderer
  /// still produces an on-theme control, and the resolver records an
  /// `adapterMissing` diagnostic so the downgrade is visible.
  final LiveUiFallbackAction onMissingAdapter;

  /// How to serve the default language when even the shared fallback is absent.
  ///
  /// Defaults to [LiveUiFallbackAction.failFast]: nothing can render it, so
  /// this is a startup-level fault (§7), never a silent blank.
  final LiveUiFallbackAction onMissingDefaultAdapter;

  /// How to serve a control a registered adapter does not declare.
  ///
  /// Defaults to [LiveUiFallbackAction.fallbackToShared]: that one control falls
  /// back to the token renderer with a `controlUnsupported` diagnostic.
  final LiveUiFallbackAction onUnsupportedControl;

  /// How to serve a structural surface — the app host or the shell — that the
  /// registered adapter does not own.
  ///
  /// Defaults to [LiveUiFallbackAction.fallbackToShared]: the shared token host or
  /// token shell stands in and a `surfaceUnsupported` diagnostic records it. This
  /// is a separate knob because the downgrade is the whole window frame rather
  /// than one widget, and a build that would rather fail than run a Material
  /// frame under a Fluent setting can set it to fail-fast on its own terms (§ surfaces).
  final LiveUiFallbackAction onUnsupportedSurface;
}
