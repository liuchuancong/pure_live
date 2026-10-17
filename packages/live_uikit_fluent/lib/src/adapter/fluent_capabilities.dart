import 'package:live_uikit/live_uikit.dart';

/// The controls `live_uikit_fluent` renders with `fluent_ui`'s own widgets, or
/// with Fluent's own primitives where the library has no widget for the job
/// (§3.1 / §7 capability declaration).
///
/// All seventeen. Twelve map onto a widget of the library. Five are not a
/// one-for-one mapping and say so in their builder: `segmented` and `navBar` are
/// composed from `ToggleButton` groups because fluent_ui has no segmented track
/// and no bottom strip — its destinations live in a `NavigationView` pane, which
/// is the shell, not this control — `appBar` is a `PageHeader` with the actions in
/// its command slot because `CommandBar` builds its own items from icons and
/// callbacks the spec does not carry, `tabBar` is a row of `HoverButton` cells
/// with Fluent's accent underline because the library's `TabView` fuses the strip
/// to a body of its own, and `tabView` is an `AnimatedSwitcher` page swap because
/// this version of the library has no `Pivot`. `dialog` does map, straight onto
/// `ContentDialog` used as a plain surface — no route of the library's own,
/// because the core's `showLiveDialog` owns routing and barrier. Composing the
/// other five here, out of Fluent's widgets and `FluentTheme`'s metrics, is what
/// keeps a Fluent window from carrying a bar some other library drew.
///
/// This must stay in sync with the methods `FluentLanguageAdapter` overrides (§17).
const LiveUiCapabilities fluentCapabilities = LiveUiCapabilities(<LiveUiControl>{
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
  LiveUiControl.dialog,
  LiveUiControl.tabView,
});
