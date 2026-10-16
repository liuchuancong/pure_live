import 'package:live_uikit/styling.dart';

/// The structural surfaces `live_uikit_fluent` owns with `fluent_ui`'s own
/// widgets (§ surfaces).
///
/// Both of them. `FluentApp` is the Windows application host, and
/// `NavigationView` is the shell the neutral spec describes — a pane of
/// destinations beside the content, with the selection and the pane footer drawn
/// by the library. Declaring them apart from the controls is the point: a library
/// can own the window frame and the navigation while still borrowing the shared
/// renderer for a segmented track, and the reverse is true of `macos_ui`, which
/// owns the host and not the bottom strip.
const LiveUiSurfaceCapabilities fluentSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{
  LiveUiSurface.appHost,
  LiveUiSurface.appShell,
});
