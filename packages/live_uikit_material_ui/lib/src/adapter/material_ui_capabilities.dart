import 'package:live_uikit/styling.dart';

/// The controls `live_uikit_material_ui` renders with native `material_ui`
/// widgets (§3.1 / §7). Everything else (select, tabs) falls back to the core
/// shared token renderer; keep in sync with the methods `MaterialUiLanguageAdapter`
/// overrides (§17).
const LiveUiCapabilities materialUiCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
  LiveUiControl.slider,
  LiveUiControl.segmented,
  LiveUiControl.progress,
});
