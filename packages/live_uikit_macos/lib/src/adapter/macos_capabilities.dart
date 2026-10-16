import 'package:live_uikit/live_uikit.dart';

/// The controls `live_uikit_macos` renders with native `macos_ui` widgets
/// (§3.1 / §7). Everything else falls back to the core shared token renderer;
/// keep in sync with the methods `MacosLanguageAdapter` overrides (§17).
///
/// Of the chrome controls, `navBar` and `toast` are deliberately absent:
/// `macos_ui` 2.x has no bottom navigation strip (its navigation surface is the
/// `Sidebar`), and its `Toast` is an overlay manager with its own `ToastOverlay`
/// host rather than a surface the contract's `toast` slot can return.
const LiveUiCapabilities macosCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.textField,
  LiveUiControl.checkbox,
  LiveUiControl.slider,
  LiveUiControl.scaffold,
  LiveUiControl.appBar,
  LiveUiControl.listRow,
});
