import 'package:live_uikit/live_uikit.dart';

/// The controls `live_uikit_forui` renders with `forui`'s own widgets, or with the
/// library's own parts where it has no widget for the job (§3.1 / §7 capability
/// declaration).
///
/// All fifteen.
///
/// Thirteen are one-for-one mappings — `FButton`, `FCard`, `FTextField`, `FSwitch`,
/// `FCheckbox`, `FSlider`, `FDeterminateProgress`/`FProgress`, `FSelect<T>`, `FScaffold`,
/// `FHeader.nested`, `FTile`, `FBottomNavigationBar`, `FToast` — where the library carries
/// the control the contract names. Two are not, and each builder says so: `segmented` is
/// composed as a row of ghost `FButton`s taking `FButton.selected`, because forui's only
/// single-choice row is `FTabs`, which is a tab *view* and is spent on `tabBar`; and
/// `tabBar` is `FTabs` itself, mapped with an empty content panel per entry, because the
/// library's tabs widget always paints a body area while this contract's body belongs to
/// the caller. `slider`, `select` and `tabBar` are handed to the library in its *lifted*
/// form, which is what keeps them controlled by the spec's value instead of by a
/// controller minted here.
///
/// Nothing in this set falls back. Keep it in sync with the methods
/// `ForuiLanguageAdapter` actually overrides (§17).
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
});
