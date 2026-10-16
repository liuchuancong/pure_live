import 'package:live_uikit/styling.dart';

/// The controls `live_uikit_material_ui` renders with native `material_ui`
/// widgets (§3.1 / §7). Everything else falls back to the core shared token
/// renderer — `select` and `tabBar` because this fork does not carry them, and
/// `toast` because Material's transient message is a `SnackBar` owned by the
/// `ScaffoldMessenger`, not a surface a `LanguageAdapter` can return.
/// Keep in sync with the methods `MaterialUiLanguageAdapter` overrides (§17).
const LiveUiCapabilities materialUiCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
  LiveUiControl.slider,
  LiveUiControl.segmented,
  LiveUiControl.progress,
  LiveUiControl.scaffold,
  LiveUiControl.appBar,
  LiveUiControl.listRow,
  LiveUiControl.navBar,
});
