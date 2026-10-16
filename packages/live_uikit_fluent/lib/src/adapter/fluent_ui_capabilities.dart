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
/// (§17). `appBar` and `navBar` are the two chrome controls left shared:
/// `fluent_ui` puts a page title inside `ScaffoldPage.header` (which this
/// adapter renders) and has no bottom navigation strip at all — its navigation
/// surface is the vertical `NavigationView`, which is a different control — so
/// neither maps to a Fluent widget without fighting the desktop window chrome
/// the composition root owns.
const LiveUiCapabilities fluentUiCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
  LiveUiControl.slider,
  LiveUiControl.progress,
  LiveUiControl.select,
  LiveUiControl.scaffold,
  LiveUiControl.listRow,
  LiveUiControl.toast,
});
