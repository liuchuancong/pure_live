import 'package:live_uikit/styling.dart';

/// The controls `live_uikit_cupertino_ui` renders with native `cupertino_ui`
/// widgets (§3.1 / §7). Everything else falls back to the core shared token
/// renderer; keep in sync with the methods `CupertinoUiLanguageAdapter`
/// overrides (§17).
const LiveUiCapabilities cupertinoUiCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.slider,
});
