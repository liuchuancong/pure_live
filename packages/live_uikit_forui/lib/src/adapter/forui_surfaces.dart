import 'package:live_uikit/live_uikit.dart';

/// The structural surfaces `live_uikit_forui` owns (§ surfaces).
///
/// The app host: forui ships no application widget at all — it is a theme plus
/// components — so the host is Flutter's `WidgetsApp` with `FTheme` above the
/// routed tree, which is what takes the page transition and the scroll physics
/// out of Material's hands (§9 app host). And the app shell: `FSidebar` turned
/// out to need nothing above `FTheme` — its items fall back to the theme's
/// sidebar style when there is no `FSidebarGroup` around them — and it paints
/// only the navigation column, never a body of its own, so the shell composes
/// `Row[FSidebar, Expanded(child)]` with the router's page on the right and
/// hands the bottom form to the library's own `FBottomNavigationBar` through
/// `navBar` (§ surfaces).
const LiveUiSurfaceCapabilities foruiSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{
  LiveUiSurface.appHost,
  LiveUiSurface.appShell,
});
