import 'package:live_uikit/live_uikit.dart';

/// The structural surfaces `live_uikit_glass` owns (§ surfaces).
///
/// Both of them. The app host: `glass_morphism_plus` ships no application widget
/// at all — it is a theme plus frosted surfaces — so the host is Flutter's
/// `WidgetsApp` with `GlassTheme` above the routed tree, which is what takes the
/// page transition, the scroll physics and the dialog barrier out of Material's
/// hands (§9 app host). The app shell: the library ships no navigation structure
/// either — only surface pieces (`GlassContainer`/`GlassTile`/`GlassDivider`) and
/// the Material `GlassAppBar` — so the shell is composed, not mapped: a full-height
/// frosted `GlassContainer` track with a brighter sheet on the selected
/// destination, the column `glass_nav_bar`/`glass_tab_bar` already build turned
/// vertical, and the bottom form handed back through `navBar`; see
/// `GlassShellBuilder`.
const LiveUiSurfaceCapabilities glassSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{
  LiveUiSurface.appHost,
  LiveUiSurface.appShell,
});
