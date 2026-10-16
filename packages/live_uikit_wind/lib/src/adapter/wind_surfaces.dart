import 'package:live_uikit/live_uikit.dart';

/// The structural surfaces `live_uikit_wind` owns (§ surfaces).
///
/// The app host, and not the shell yet. `fluttersdk_wind` is a styling library:
/// it ships no application widget, so the host is Flutter's `WidgetsApp` with a
/// `WindTheme` scope above the routed tree, which is what takes the page
/// transition, the scroll physics and the dialog barrier out of Material's hands
/// (§9 app host). The shell stays with the shared renderer: the library has no
/// navigation structure of its own to bind a router-owned body to, only styled
/// parts, so a Wind page's bars are native while the app around them is not.
const LiveUiSurfaceCapabilities windSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{LiveUiSurface.appHost});
