import 'package:live_uikit/src/styling/diagnostics/diagnostics.dart' show LiveUiControl;

/// The controls an adapter renders with a native widget from its own library
/// (§3.1 / §7 capability declaration).
///
/// A capability is a *declaration of fact*: which controls the adapter
/// overrides with its library's own widgets. There is nothing behind it — no
/// shared renderer to serve what is missing — so an undeclared control is a
/// `LiveUiCapabilityException` rather than a silent degrade, and the resolver
/// checks the declaration against the method (§15.3). Adapters must keep this set
/// in sync with what they override: §17 makes that a CI assertion, §16 a test.
final class LiveUiCapabilities {
  /// The controls rendered natively by an adapter.
  const new(this.supported);

  /// A declaration with no native controls. No adapter uses it: it exists for a
  /// test that wants to assert the resolver rejects an empty declaration.
  // ignore: unnecessary_type_name_in_constructor
  const LiveUiCapabilities.none() : supported = const <LiveUiControl>{};

  /// The controls this adapter builds with its library's real widgets.
  final Set<LiveUiControl> supported;

  /// Whether [control] is rendered natively. An unsupported one is not
  /// substituted: `requireControl` raises.
  bool supports(LiveUiControl control) => supported.contains(control);
}
