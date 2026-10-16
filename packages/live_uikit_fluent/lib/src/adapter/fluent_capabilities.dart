import 'package:live_uikit/live_uikit.dart';

/// The controls `live_uikit_fluent` renders with `fluent_ui`'s own widgets, or
/// with Fluent's own primitives where the library has no widget for the job
/// (§3.1 / §7 capability declaration).
///
/// All fifteen. Four of them are not a one-for-one mapping and say so in their
/// builder: `segmented` and `navBar` are composed from `ToggleButton` groups
/// because fluent_ui has no segmented track and no bottom strip — its
/// destinations live in a `NavigationView` pane, which is the shell, not this
/// control — and `appBar` is a `PageHeader` with the actions in its command slot
/// because `CommandBar` builds its own items from icons and callbacks the spec
/// does not carry. `tabBar` is `TabView` with the browser affordances switched
/// off. Composing them here, out of Fluent's widgets and `FluentTheme`'s
/// metrics, is what keeps a Fluent window from having a Material bar in it.
///
/// This must stay in sync with the methods `FluentLanguageAdapter` actually
/// overrides (§17).
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
});
