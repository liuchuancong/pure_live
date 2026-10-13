import 'package:live_uikit/styling.dart';

/// The controls `live_uikit_macos` renders with native `macos_ui` widgets
/// (§3.1 / §7). Everything else falls back to the core shared token renderer;
/// keep in sync with the methods `MacosLanguageAdapter` overrides (§17).
const LiveUiCapabilities macosUiCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.textField,
  LiveUiControl.checkbox,
  LiveUiControl.slider,
});
