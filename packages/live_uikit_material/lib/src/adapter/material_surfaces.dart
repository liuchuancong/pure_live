import 'package:live_uikit/styling.dart';

/// The structural surfaces `live_uikit_material` owns with `material_ui`'s own
/// widgets (§ surfaces).
///
/// The app host only, for now. The fork ships `NavigationRail`, `Drawer` and
/// `NavigationDestination`, so a native Material shell is reachable — but this
/// language and the shared token base paint the same design system, so the shell
/// is the last place where a native rendering earns its keep; the token shell
/// already reads as Material, and the value of swapping it is measured in the
/// fork's own theme scope rather than in appearance.
const LiveUiSurfaceCapabilities materialSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{LiveUiSurface.appHost});
