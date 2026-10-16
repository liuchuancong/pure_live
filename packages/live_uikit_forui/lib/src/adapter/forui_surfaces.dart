import 'package:live_uikit/live_uikit.dart';

/// The structural surfaces `live_uikit_forui` owns (§ surfaces).
///
/// The app host, and not the shell yet. forui ships no application widget at
/// all — it is a theme plus components — so the host is Flutter's `WidgetsApp`
/// with `FTheme` above the routed tree, which is what takes the page transition
/// and the scroll physics out of Material's hands (§9 app host). The shell stays
/// with the shared renderer until the library's own navigation widget is wired to
/// a body the router owns rather than to one the tabs own.
const LiveUiSurfaceCapabilities foruiSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{LiveUiSurface.appHost});
