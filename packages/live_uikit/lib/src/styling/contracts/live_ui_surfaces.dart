import 'package:live_uikit/src/styling/contracts/live_ui_capabilities.dart';
import 'package:live_uikit/src/styling/diagnostics/live_ui_diagnostic_event.dart' show LiveUiControl;

/// The two structural surfaces a design language can own, kept out of
/// [LiveUiControl] on purpose (§11 of the app-host/shell design).
///
/// A control is something a page places — a button, a field, a row. A surface is
/// something the page sits *in*: the app widget that owns the router, or the
/// shell that owns the navigation. They are decided by different libraries,
/// can be supported independently of each other and of any control, and a
/// downgrade on one changes what the whole window looks like rather than one
/// widget — which is why they get their own declaration, their own resolution
/// and their own diagnostic.
enum LiveUiSurface {
  /// The application host: the router, the overlay, the chrome's strings.
  appHost,

  /// The application shell: the navigation structure around the page body.
  appShell,
}

/// Which structural surfaces an adapter draws with its own library (§7).
///
/// Same declaration rule as [LiveUiCapabilities]: it states what the adapter
/// actually overrides, the architecture guard asserts the set matches the
/// methods (§17), and a claim the adapter cannot serve is a
/// `LiveUiCapabilityException`. An adapter that owns the host but not the shell
/// was the normal case while the floor existed; now both have to be answered,
/// which is why `live_uikit_forui` hosts itself on `WidgetsApp` rather than
/// settling for someone else's window.
final class LiveUiSurfaceCapabilities {
  /// The surfaces rendered natively by an adapter.
  const new(this.supported);

  /// A declaration with no native surface. No adapter uses it: it exists for a
  /// test that wants to assert a claimed surface is checked.
  // ignore: unnecessary_type_name_in_constructor
  const LiveUiSurfaceCapabilities.none() : supported = const <LiveUiSurface>{};

  /// The surfaces this adapter builds with its library's real widgets.
  final Set<LiveUiSurface> supported;

  /// Whether [surface] is rendered natively.
  bool supports(LiveUiSurface surface) => supported.contains(surface);
}
