import 'package:live_uikit/live_uikit.dart';

/// The controls `live_uikit_neumorphic` renders with `flutter_neumorphic_ui_kit`'s
/// own widgets, or with that library's own primitives where it has no widget for
/// the job (§3.1 / §7 capability declaration).
///
/// This is the whole contract: the language renders every control the resolver can
/// ask for, so nothing in a Neumorphic page reaches the shared token renderer and no
/// control is reported as a `controlUnsupported` downgrade (§15.3).
///
/// Eight are mappings to a widget the library ships — `button`, `card`,
/// `textField`, `switchWidget`, `checkbox`, `slider`, `progress` (`NeuProgressBar` is
/// already a recessed trough with a domed fill) and `appBar` (`NeuAppBar` is a
/// `NeuContainer` plane around a `NavigationToolbar`, inline-renderable, with every
/// spec field but `bottom` in a slot of its own).
///
/// Seven are composed out of that library's own faces and values, and each builder
/// says why it had to be: `segmented` (a `pressed` dish of cells, the chosen one
/// domed `convex`), `select` (a field plane plus an option dish that opens inline —
/// the core owns the overlay), `tabBar` (a row of `NeuContainer` cells, the chosen
/// one domed; `NeuBottomNav` cannot be a strip), `toast` (a raised plane; the core
/// keeps the overlay, the fade and the timer), `navBar` (a docked slab whose active
/// destination sinks into a `pressed` dish — the opposite of the tab strip's dome),
/// `listRow` (a flat plane that turns into a `pressed` dish when selected, since this
/// style states an active thing with depth rather than with a fill), and `scaffold`
/// (the page surface itself: a flat `NeuContainer` at zero depth and zero radius,
/// with the dispatched bars stacked on it, because the library has no frame and
/// Material's would undo the dispatch).
///
/// All of them read `NeuTheme.of` for base colour, accent, depth, distance and radius,
/// so they stay on the token through the theme scope even where the library has no
/// widget to place. This must stay in sync with the methods
/// `NeumorphicLanguageAdapter` actually overrides (§17).
const LiveUiCapabilities neumorphicCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
  LiveUiControl.slider,
  LiveUiControl.segmented,
  LiveUiControl.progress,
  LiveUiControl.select,
  LiveUiControl.tabBar,
  LiveUiControl.scaffold,
  LiveUiControl.appBar,
  LiveUiControl.listRow,
  LiveUiControl.navBar,
  LiveUiControl.toast,
});
