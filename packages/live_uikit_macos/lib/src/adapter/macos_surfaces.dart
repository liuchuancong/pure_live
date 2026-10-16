import 'package:live_uikit/live_uikit.dart';

/// The structural surfaces `live_uikit_macos` owns with `macos_ui`'s own widgets
/// (§ surfaces).
///
/// The app host only. `MacosApp` is the library's window-level root, but its
/// navigation widget is `Sidebar` — a child of `MacosWindow`, sized and themed
/// for that frame, with a different selection model and no bottom strip at all.
/// A macOS shell therefore means deciding who owns the window frame (the shell or
/// the page), which is a design question the spec does not yet answer; until it
/// does the shell falls back to the shared token renderer and says so through the
/// `surfaceUnsupported` diagnostic rather than pretending to be native.
const LiveUiSurfaceCapabilities macosSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{LiveUiSurface.appHost});
