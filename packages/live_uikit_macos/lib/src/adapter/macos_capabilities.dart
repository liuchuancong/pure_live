import 'package:live_uikit/live_uikit.dart';

/// The controls `live_uikit_macos` renders with `macos_ui`'s own widgets, or with
/// macOS's own primitives where the library has no widget for the job
/// (§3.1 / §7 capability declaration).
///
/// All fifteen. Eleven are a one-for-one mapping — `PushButton`, `MacosTextField`,
/// `MacosSwitch`, `MacosCheckbox`, `MacosSlider`, `MacosSegmentedControl`,
/// `ProgressBar`/`ProgressCircle`, `MacosPopupButton`, `MacosScaffold`, `ToolBar`
/// and `MacosListTile`. Four are composed out of the library's parts because
/// `macos_ui` 2.2.2 has no such widget, and each builder says why: the card and
/// the toast surface are the library's own floating panel, `MacosSheet`, mounted
/// inline (there is no `MacosCard`, no `MacosBox` and no toast of any kind in the
/// library); the tab strip and the destination strip are rows of the library's own
/// `MacosTab` cell with its `MacosIcon` in front, because `MacosTabView` is a whole
/// tab *view* with one body per tab while this contract's strip has no bodies, and
/// `MacosSegmentedControl` — the real strip — has a text-only cell and moves its
/// own selection on tap. `macos_ui` also has no bottom bar: its destinations are
/// the window-frame `Sidebar`, which is the shell surface, not this control.
///
/// Two spec shapes still reach the shared renderer, and both are the library
/// refusing rather than the adapter not trying: a slider with no callback
/// (`MacosSlider.onChanged` is required) and a select whose current value is not
/// one of its items or whose items repeat, which `MacosPopupButton` asserts on.
///
/// This must stay in sync with the methods `MacosLanguageAdapter` actually
/// overrides (§17).
const LiveUiCapabilities macosCapabilities = LiveUiCapabilities(<LiveUiControl>{
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
