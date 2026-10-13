import 'package:live_uikit/src/styling/diagnostics.dart' show LiveUiControl;

/// The controls an adapter renders with a native widget from its own library
/// (§3.1 / §7 capability declaration).
///
/// A capability is a *declaration of fact*: which controls the adapter
/// overrides natively. Everything not listed is served by the core shared token
/// renderer, and the `LiveUiResolver` reports a `controlUnsupported` diagnostic
/// for those (§15.3 step 2b) rather than silently degrading. Adapters must keep
/// this set in sync with the methods they actually override — §17 makes that a
/// CI assertion, and §16 a test.
final class LiveUiCapabilities {
  /// The controls rendered natively by an adapter.
  const new(this.supported);

  /// A declaration with no native controls — every control falls back to the
  /// shared token renderer. This is the base adapter's own capability.
  // ignore: unnecessary_type_name_in_constructor
  const LiveUiCapabilities.none() : supported = const <LiveUiControl>{};

  /// The controls this adapter builds with its library's real widgets.
  final Set<LiveUiControl> supported;

  /// Whether [control] is rendered natively (otherwise the shared renderer is
  /// used for it).
  bool supports(LiveUiControl control) => supported.contains(control);
}
