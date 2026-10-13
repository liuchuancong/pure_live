import 'package:live_uikit/styling.dart';

/// The controls `live_uikit_fluent` renders with native `fluent_ui` widgets
/// (§3.1 / §7 capability declaration).
///
/// Everything absent from this set is served by the core shared token renderer;
/// the resolver reports a `controlUnsupported` diagnostic for those rather than
/// degrading silently (§15.3). `segmented` and `tabBar` sit in that group:
/// fluent_ui ships no single-choice segmented track, and its `TabView` renders a
/// whole tab *view* (per-tab bodies plus a filling body area), not a strip. This
/// must stay in sync with the methods `FluentLanguageAdapter` actually overrides
/// (§17).
const LiveUiCapabilities fluentUiCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
  LiveUiControl.slider,
  LiveUiControl.progress,
  LiveUiControl.select,
});
