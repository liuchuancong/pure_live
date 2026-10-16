import 'package:live_uikit/live_uikit.dart';

/// The controls `live_uikit_material` renders with `material_ui`'s own widgets
/// (§3.1 / §7). All seventeen.
///
/// `select` is `DropdownButton`, `tabBar` is `TabBar` — which the fork drives
/// with a `TabController` rather than an index, so the adapter owns one and
/// asserts the spec's index onto it (§9 Tabs) — and `toast` is a `mu.Material`
/// card themed by the fork's own `SnackBarThemeData`, because the contract asks
/// the language for the message's surface while the core keeps the overlay and
/// the timer, and `mu.SnackBar` cannot be built without the animation a
/// `ScaffoldMessenger` owns.
///
/// `dialog` is the same split: `mu.AlertDialog` is an ordinary widget, so the
/// adapter hands back the surface and `showLiveDialog` keeps the route, the
/// barrier, the transition and the centred frame (§9 Dialog). `tabView` is
/// `TabBarView` behind a second `TabController` of its own — the strip and the
/// view are two controls, each following the index its spec carries, so neither
/// borrows the other's controller.
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
  LiveUiControl.tabView,
  LiveUiControl.dialog,
  LiveUiControl.scaffold,
  LiveUiControl.appBar,
  LiveUiControl.listRow,
  LiveUiControl.navBar,
  LiveUiControl.toast,
});
