import 'package:live_uikit/live_uikit.dart';

/// The controls `live_uikit_material` renders with `material_ui`'s own widgets
/// (§3.1 / §7). All fifteen.
///
/// `select` is `DropdownButton`, `tabBar` is `TabBar` — which the fork drives
/// with a `TabController` rather than an index, so the adapter owns one and
/// asserts the spec's index onto it (§9 Tabs) — and `toast` is a `mu.Material`
/// card themed by the fork's own `SnackBarThemeData`, because the contract asks
/// the language for the message's surface while the core keeps the overlay and
/// the timer, and `mu.SnackBar` cannot be built without the animation a
/// `ScaffoldMessenger` owns.
///
/// Keep in sync with the methods `MaterialLanguageAdapter` overrides (§17).
const LiveUiCapabilities materialCapabilities = LiveUiCapabilities(<LiveUiControl>{
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
