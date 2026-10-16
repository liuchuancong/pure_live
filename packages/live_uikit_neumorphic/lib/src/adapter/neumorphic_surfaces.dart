import 'package:live_uikit/live_uikit.dart';

/// The structural surfaces `live_uikit_neumorphic` owns (§ surfaces).
///
/// Both of them. `flutter_neumorphic_ui_kit` ships no application widget at all —
/// it is a theme plus components — so the host is Flutter's `WidgetsApp` with
/// `NeuTheme` above the routed tree, which is what takes the page transition and
/// the scroll physics out of Material's hands (§9 app host).
///
/// The shell is composed for the same reason the nav bar and the tab strip are:
/// the library has no rail, no sidebar and no `NavigationView`, and its single
/// navigation widget, `NeuBottomNav`, is a horizontal floating pill that asserts
/// two items, demands a non-null callback, adds its own `SafeArea` and inset and
/// fires `HapticFeedback` — none of which the shell contract asks for. So the
/// column is assembled out of the library's own faces, a flat plane holding one
/// cell per destination with the chosen one sunk to `pressed` in the theme's
/// accent, and the phone form goes back through this package's `navBar`; see
/// `NeumorphicShellBuilder`.
const LiveUiSurfaceCapabilities neumorphicSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{
  LiveUiSurface.appHost,
  LiveUiSurface.appShell,
});
