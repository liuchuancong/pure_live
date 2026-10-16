import 'package:live_uikit/styling.dart';

/// The controls `live_uikit_forui` renders with native `forui` widgets (§3.1 / §7).
/// Everything else falls back to the core shared token renderer; keep in sync with the
/// methods `ForuiLanguageAdapter` overrides (§17).
const LiveUiCapabilities foruiCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
});
