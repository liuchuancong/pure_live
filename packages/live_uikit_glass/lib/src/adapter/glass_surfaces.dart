import 'package:live_uikit/live_uikit.dart';

/// The structural surfaces `live_uikit_glass` owns (§ surfaces).
///
/// The app host, and not the shell yet. `glass_morphism_plus` ships no
/// application widget at all — it is a theme plus frosted surfaces — so the host
/// is Flutter's `WidgetsApp` with `GlassTheme` above the routed tree, which is
/// what takes the page transition, the scroll physics and the dialog barrier out
/// of Material's hands (§9 app host). The shell is still the shared token one:
/// the library's only structural widget is `GlassAppBar`, a Material `AppBar`
/// under a frosted `flexibleSpace`, so no glass widget of this package's wraps a
/// router-owned body yet.
const LiveUiSurfaceCapabilities glassSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{LiveUiSurface.appHost});
