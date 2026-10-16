import 'package:live_uikit/live_uikit.dart';

/// The structural surfaces `live_uikit_cupertino` owns with `cupertino_ui`'s own
/// widgets (§ surfaces).
///
/// Both of them. `CupertinoApp` is the iOS application host, and the shell is the
/// column this package composes out of the library's surface pieces —
/// `cupertino_ui` has no rail widget: its two shell-shaped pieces,
/// `CupertinoTabScaffold` and `CupertinoTabBar`, are both the *bottom* bar, and
/// the scaffold adds a `CupertinoTabView` body per tab, which is the opposite of
/// the router-owned body the contract carries. So the pane is built from a
/// `CupertinoListSection` of `CupertinoListTile` rows and the strip goes back
/// through `navBar`; see `CupertinoShellBuilder`.
const LiveUiSurfaceCapabilities cupertinoSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{
  LiveUiSurface.appHost,
  LiveUiSurface.appShell,
});
