import 'package:live_uikit/styling.dart';

/// The controls `live_uikit_wind` renders with native `fluttersdk_wind` widgets
/// (§3.1 / §7). Everything else falls back to the core shared token renderer;
/// keep in sync with the methods `WindLanguageAdapter` overrides (§17).
const LiveUiCapabilities windUiCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
  LiveUiControl.select,
});
