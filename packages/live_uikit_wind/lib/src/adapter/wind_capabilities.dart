import 'package:live_uikit/live_uikit.dart';

/// The controls `live_uikit_wind` renders with `fluttersdk_wind`'s own parts,
/// whether the library has a widget for the job or not (§3.1 / §7 capability
/// declaration).
///
/// All seventeen. Six are mappings — `button` is `WButton`, `card` is `WCard` over
/// the token surface, `textField` is `WInput`, `switchWidget` is `WSwitch`,
/// `checkbox` is `WCheckbox` and `select` is `WSelect<T>`. The other eleven are
/// compositions, because the fork is a styling library and ships no slider,
/// segmented track, progress bar, tab strip, page frame, top bar, list row,
/// bottom bar, toast, dialog surface or page switcher: each of those is assembled
/// out of the library's own pieces — `WDiv` and `WCard` surfaces, the `WAnchor` its
/// own controls are built on, `WText`/`WIcon` leaves, `WButton` for a segment —
/// coloured from Wind's Tailwind maps (`bg-primary-500`, which reaches this
/// subtree as the token accent through `WindThemeBuilder`, the
/// `bg-gray-*`/`dark:bg-gray-*` surface pairs, `rounded-*`, `border-*`, `shadow`)
/// and driven through its `hover:` / `selected:` / `disabled:` state prefixes. A
/// builder says which it is and what it used (§9).
///
/// The dialog is the `WCard` panel of `rounded-xl shadow-xl border` over the
/// library's elevated pair — the fork has no modal, and the one floating thing it
/// has, `WPopover`, is anchored rather than centred — and only the surface: the
/// route, the barrier, the fade-and-scale and the dismissal stay with core's
/// `showLiveDialog`. The tab view is Flutter's `PageView` inside the library's own
/// full-size column, because `WTabs` welds a strip to its panel and the core hands
/// the two separately.
///
/// Composing them here, rather than leaving them to the shared renderer, is what
/// keeps a Wind page from having a Material-shaped bar in it.
///
/// This must stay in sync with the methods `WindLanguageAdapter` actually
/// overrides (§17).
const LiveUiCapabilities windCapabilities = LiveUiCapabilities(<LiveUiControl>{
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
