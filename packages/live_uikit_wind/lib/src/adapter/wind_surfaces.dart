import 'package:live_uikit/live_uikit.dart';

/// The structural surfaces `live_uikit_wind` owns (§ surfaces).
///
/// Both of them. `fluttersdk_wind` is a styling library: it ships no application
/// widget, so the host is Flutter's `WidgetsApp` with a `WindTheme` scope above
/// the routed tree, which is what takes the page transition, the scroll physics
/// and the dialog barrier out of Material's hands (§9 app host).
///
/// The shell has the same shape, one level down: the library has no navigation
/// structure — no rail, no sidebar, nothing that binds a column of destinations
/// to a body — only styled parts, so a Wind page's bars were native while the app
/// around them was not. The column is therefore composed out of those parts the
/// way this package's nav bar and tab strip are, and the bottom form goes back
/// through `navBar`; see `WindShellBuilder`.
const LiveUiSurfaceCapabilities windSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{
  LiveUiSurface.appHost,
  LiveUiSurface.appShell,
});
