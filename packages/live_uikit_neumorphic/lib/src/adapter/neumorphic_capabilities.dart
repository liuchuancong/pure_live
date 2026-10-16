import 'package:live_uikit/live_uikit.dart';

/// The controls `live_uikit_neumorphic` renders with native
/// `flutter_neumorphic_ui_kit` widgets (§3.1 / §7). Everything else falls back to
/// the core shared token renderer; keep in sync with the methods
/// `NeumorphicLanguageAdapter` overrides (§17).
const LiveUiCapabilities neumorphicCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
  LiveUiControl.slider,
});
