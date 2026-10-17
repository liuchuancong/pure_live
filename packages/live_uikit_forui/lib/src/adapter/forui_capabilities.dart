import 'package:live_uikit/live_uikit.dart';

/// The controls `live_uikit_forui` renders with `forui`'s own widgets, or with the
/// library's own parts where it has no widget for the job (§3.1 / §7 capability
/// declaration).
///
/// All seventeen.
///
/// Fourteen are one-for-one mappings — `FButton`, `FCard`, `FTextField`, `FSwitch`,
/// `FCheckbox`, `FSlider`, `FDeterminateProgress`/`FProgress`, `FSelect<T>`, `FScaffold`,
/// `FHeader.nested`, `FTile`, `FBottomNavigationBar`, `FToast`, `FDialog` — where the
/// library carries the control the contract names. Three are not, and each builder says
/// so: `segmented` is composed as a row of ghost `FButton`s taking `FButton.selected`,
/// because forui's only single-choice row is `FTabs`, which is a tab *view* and is spent
/// on `tabBar`; `tabBar` is `FTabs` itself mapped with an empty content panel per entry,
/// because the library's tabs widget always paints a body area while this contract's
/// body belongs to the caller; and `tabView` is the widgets-layer `PageView` for the
/// mirror-image reason — the library's only page switcher is that same `FTabs`, whose
/// panels hang off labels a page switcher is never given, so the caller's pages are
/// swiped as they were built. `dialog` maps onto `FDialog`'s frame but composes the
/// inside of it, since 0.27.5's frame carries no content padding and no action area, and
/// the route, the barrier and the fade stay in the core (`showLiveDialog`) rather than
/// becoming `FDialogRoute`/`showFDialog` here. `slider`, `select` and `tabBar` are handed
/// to the library in its *lifted* form, which is what keeps them controlled by the spec's
/// value instead of by a controller minted here.
///
/// This set is the whole contract — every control the resolver can ask this language
/// for is in it. Keep it in sync with the methods `ForuiLanguageAdapter` actually
/// overrides (§17).
const LiveUiCapabilities foruiCapabilities = LiveUiCapabilities(<LiveUiControl>{
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
