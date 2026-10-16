import 'package:live_uikit/live_uikit.dart';

/// The controls `live_uikit_cupertino` renders with `cupertino_ui`'s own widgets,
/// or with Cupertino's own primitives where the library has no widget for the job
/// (§3.1 / §7 capability declaration).
///
/// All seventeen. Twelve of them are a one-for-one mapping: `button`, `textField`,
/// `switchWidget`, `slider`, `scaffold`, `appBar`, `listRow` and `navBar` (the
/// library's single index-controlled strip, `CupertinoTabBar`, which is a *bottom*
/// bar) were already there, and `checkbox` is `CupertinoCheckbox` — the fork's
/// only checkbox, documented as macOS-styled because the iOS HIG has no checkbox
/// at all, and still the widget a Cupertino subtree has to answer with rather than
/// a Material box. `progress` is mapped in both of its states, to
/// `CupertinoLinearActivityIndicator` for a known fraction and to
/// `CupertinoActivityIndicator` for a null one, `segmented` is
/// `CupertinoSegmentedControl`, and `dialog` is `CupertinoAlertDialog` — the
/// fork's alert card, which is a plain widget with no route in it, so it can be
/// handed back as the surface the core's `showLiveDialog` frames and needs only
/// the fork's localizations for its semantics label, not a `CupertinoApp`.
///
/// Five are composed here rather than mapped, and each builder says why: `card` is
/// `CupertinoListSection.insetGrouped` — the 10pt panel Notes and Reminders drop
/// each row into — because the fork ships no card and no box widget; `select` is a
/// `CupertinoMenuAnchor` of `CupertinoMenuItem`s behind a `CupertinoButton`,
/// because iOS chooses from a pull-down menu rather than from a field that expands
/// under it (`CupertinoPicker` is a wheel and cannot be the single inline widget
/// the contract asks for); `toast` is the library's `CupertinoPopupSurface`, the
/// blurred 13pt HUD panel, because `CupertinoToast` belongs to a community package
/// and not to this fork; `tabBar` is a row of `CupertinoButton`s with the current
/// tab bold and tinted, because the library's one strip was already taken by
/// `navBar` and an in-page iOS tab strip is not a bottom bar; and `tabView` is a
/// `PageView` wearing `CupertinoScrollBehavior`, because the fork's
/// `CupertinoTabView` is a per-tab `Navigator` that takes its content from a route
/// table — the contract hands the pages over already built and lets the caller own
/// the index, which no widget of that shape can do.
///
/// This must stay in sync with the methods `CupertinoLanguageAdapter` actually
/// overrides (§17).
const LiveUiCapabilities cupertinoCapabilities = LiveUiCapabilities(<LiveUiControl>{
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
  LiveUiControl.slider,
  LiveUiControl.segmented,
  LiveUiControl.progress,
  LiveUiControl.select,
  LiveUiControl.tabBar,
  LiveUiControl.scaffold,
  LiveUiControl.appBar,
  LiveUiControl.listRow,
  LiveUiControl.navBar,
  LiveUiControl.toast,
  LiveUiControl.dialog,
  LiveUiControl.tabView,
});
