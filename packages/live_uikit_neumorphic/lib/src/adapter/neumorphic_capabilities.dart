import 'package:live_uikit/live_uikit.dart';

/// The controls `live_uikit_neumorphic` renders with `flutter_neumorphic_ui_kit`'s
/// own widgets, or with that library's own primitives where it has no widget for
/// the job (§3.1 / §7 capability declaration).
///
/// Seven are mappings — `button`, `card`, `textField`, `switchWidget`,
/// `checkbox`, `slider`, `progress` (`NeuProgressBar` is already a recessed trough
/// with a domed fill). Four are composed out of `NeuContainer`/`NeuShape` faces and
/// `NeuTheme` values, and each builder says why: `segmented` (the library has no
/// segmented track), `select` (no dropdown, and no anchored popover either — the
/// option list opens inline because the core owns the overlay), `tabBar`
/// (`NeuBottomNav` is a docked bar that asserts ≥2 items, a non-null callback and
/// an icon per item) and `toast` (no transient surface in the library; the core
/// keeps the overlay, the fade and the timer).
///
/// Everything absent from this set is served by the core shared token renderer; the
/// resolver reports a `controlUnsupported` diagnostic for those rather than degrading
/// silently (§15.3). The four left are the chrome pieces — `scaffold`, `appBar`,
/// `listRow`, `navBar`. This must stay in sync with the methods
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
  LiveUiControl.toast,
});
