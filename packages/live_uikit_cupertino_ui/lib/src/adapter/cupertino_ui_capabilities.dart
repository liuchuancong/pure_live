import 'package:live_uikit/styling.dart';

/// The controls `live_uikit_cupertino_ui` renders with native `cupertino_ui`
/// widgets (§3.1 / §7). Everything else falls back to the core shared token
/// renderer — including `toast`, because iOS shows a transient message through a
/// `CupertinoToast`-style overlay host rather than a surface the contract can
/// hand back. Keep in sync with the methods `CupertinoUiLanguageAdapter`
/// overrides (§17).
const LiveUiCapabilities cupertinoUiCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.slider,
  LiveUiControl.scaffold,
  LiveUiControl.appBar,
  LiveUiControl.listRow,
  LiveUiControl.navBar,
  LiveUiControl.appHost,
});
