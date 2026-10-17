import 'package:live_uikit/live_uikit.dart';

/// The structural surfaces `live_uikit_fluent` owns with `fluent_ui`'s own
/// widgets (§ surfaces).
///
/// Both of them. `FluentApp` is the Windows application host, and
/// `NavigationView` is the shell the neutral spec describes — a pane of
/// destinations beside the content, with the selection drawn by the library.
/// Declaring them apart from the controls is the point: a host is the window a
/// control sits in, a shell is the navigation around a page, and neither answer
/// tells the resolver anything about the other, so each set is checked against
/// its own methods (§7/§17).
const LiveUiSurfaceCapabilities fluentSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{
  LiveUiSurface.appHost,
  LiveUiSurface.appShell,
});
