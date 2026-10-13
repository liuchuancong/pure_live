/// The application's own tray artwork and the bundle keys that reach it.
///
/// A tray mark is brand identity, not a shell concern, so it lives with the app
/// that owns the brand rather than inside `live_shell_desktop` — that package
/// only knows how to hand an asset path to `tray_manager`, and it must not
/// hard-code which mark a given product shows. [trayIconAssets] builds the map
/// that is passed to `TrayManagerHost.iconAssets`.
library;

import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart' show TrayIconState;

/// Where the tray artwork sits once Flutter has bundled it.
///
/// `tray_manager` loads an icon by joining the given key onto the app's
/// `data/flutter_assets` directory, so an asset declared in the application's
/// pubspec is reached at its declared path — no `packages/<package>/` prefix,
/// because these files belong to the app rather than to a package.
const String _assetRoot = 'assets/tray';

/// The Windows tray icon, as a multi-size `.ico`.
///
/// Five sizes (16, 20, 24, 32, 48) are packed as 32-bit DIB entries rather than
/// a single 32px image or PNG-compressed entries: the notification area draws at
/// 16px on a 100% display and at 32px on a 200% one, and a container holding one
/// size gets resampled by the shell — which is how a crisp mark turns into mush
/// at exactly the scaling settings where the app is most used.
const String windowsTrayIcon = '$_assetRoot/pure_live.ico';

/// The macOS menu bar icon, at 22 pixels.
const String macOSMenuIcon = '$_assetRoot/pure_live_22.png';

/// The macOS menu bar icon at retina resolution.
const String macOSMenuIconRetina = '$_assetRoot/pure_live_44.png';

/// The icon assets for [platform], keyed by state.
///
/// It is deliberately a starting point with **one mark for every state**. The
/// point of `TrayIconState` is that `recording` must be readable at a glance in a
/// 16-pixel square, and that needs tinted artwork; drop a `pure_live_recording.ico`
/// beside these and add it to the returned map when that art exists. Until then
/// every state shows the same icon and the tooltip is the only thing that changes,
/// which the host handles by leaving the icon alone for states it has no asset for.
///
/// The macOS menu bar wants its own mark; the multi-size `.ico` is a Windows
/// artefact and Linux reads it without complaint.
Map<TrayIconState, String> trayIconAssets(PlatformKind platform) =>
    platform == PlatformKind.macos ? {TrayIconState.idle: macOSMenuIcon} : {TrayIconState.idle: windowsTrayIcon};
