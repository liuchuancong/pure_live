import 'package:live_uikit/styling.dart';

/// The structural surfaces `live_uikit_cupertino` owns with `cupertino_ui`'s own
/// widgets (§ surfaces).
///
/// The app host only. `CupertinoTabScaffold` is the library's shell-shaped
/// widget, but it is bound to a bottom tab bar of two to five destinations and a
/// `CupertinoTabView` per tab — a body of its own, which is the opposite of the
/// router-owned body this contract carries. It can serve the phone form later; on
/// a desktop or TV window iOS offers no navigation column, so the shell stays with
/// the shared token renderer and reports `surfaceUnsupported`.
const LiveUiSurfaceCapabilities cupertinoSurfaces = LiveUiSurfaceCapabilities(<LiveUiSurface>{LiveUiSurface.appHost});
