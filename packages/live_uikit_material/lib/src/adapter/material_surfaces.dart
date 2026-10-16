import 'package:live_uikit/live_uikit.dart';

/// The structural surfaces `live_uikit_material` owns with `material_ui`'s own
/// widgets (§ surfaces).
///
/// Both of them. `MaterialApp` is the application host, and the shell is the
/// fork's `NavigationRail` — a destination column with the Material 3 indicator
/// and a real footer slot — falling back to its `NavigationBar` when the caller
/// asks for a bottom strip. Declaring the shell here says something the control
/// list cannot: the rail is the one place the fork's own theme scope has to be
/// the one painting, because a token rail beside a fork `Scaffold` reads as two
/// design systems in one window.
const LiveUiSurfaceCapabilities materialSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{
  LiveUiSurface.appHost,
  LiveUiSurface.appShell,
});
