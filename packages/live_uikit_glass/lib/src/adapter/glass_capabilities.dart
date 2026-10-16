import 'package:live_uikit/live_uikit.dart';

/// The controls `live_uikit_glass` renders with `glass_morphism_plus` (§3.1 /
/// §7 capability declaration).
///
/// All seventeen, but only four of them are a library widget: `button`, `card`,
/// `text field` and `list row` are the `GlassButton`, `GlassCard`,
/// `GlassTextField` and `GlassListTile` the package ships. `glass_morphism_plus`
/// is a surface library — it publishes frosted sheets and a theme that describes
/// them — so the other thirteen are composed here out of [LiveBox] over its own
/// `GlassContainer`, taking blur, tint, corner radius, stroke and shadow from
/// `GlassTheme` and geometry from the component tokens: `switchWidget`, `checkbox`
/// and `slider` are sheets with a sheet inside them, `segmented`, `tabBar` and
/// `navBar` put the chosen item on a brighter sheet, `select` opens its option list
/// as a second sheet in flow rather than in an overlay, `progress` is a groove with
/// a solid fill and a marquee for an indeterminate value, `scaffold` and `appBar`
/// are the page and header sheets, `toast` is a pill, and `dialog` and `tabView`
/// are the floating panel and the paged sheet under them.
///
/// Neither of the last two has anything to map onto: version 0.1.0 of the library
/// is eight files — three surfaces, four controls, a theme and a Material
/// `GlassAppBar` — with no dialog, alert, sheet or page switcher in it. The
/// dialog is a frosted `GlassContainer` panel and the view is the framework's own
/// `PageView` (`package:flutter/widgets.dart`) on a frosted sheet, because iOS —
/// the phone this language is the frosted reading of — swipes between tab pages.
/// Both stay surfaces: the route, the barrier, the fade-and-scale, the outside tap
/// and the timeout are the core's (`showLiveDialog` frames the child it is handed),
/// and the index of a view stays the caller's.
///
/// `GlassAppBar` is deliberately not used for `appBar`, even though its name
/// suggests it is this language's bar: it is a Material `AppBar` with a frosted
/// `flexibleSpace`, it asserts `No MaterialLocalizations found.` outside a Material
/// host, it takes the loose constraints a bar is handed rather than its own height,
/// and its `bottom` slot wants a `PreferredSizeWidget` rather than the dispatched
/// strip the spec carries. Composing the bar out of the library's surface is what
/// keeps this language from borrowing the shared renderer's shape (§15).
///
/// Keep in sync with the methods `GlassLanguageAdapter` overrides (§17).
const LiveUiCapabilities glassCapabilities = LiveUiCapabilities(<LiveUiControl>{
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
