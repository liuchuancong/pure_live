import 'package:live_shell/live_shell.dart';

/// Where this package keeps its own assets once Flutter has bundled them.
///
/// `tray_manager` loads an icon by joining the given key onto the app's
/// `data/flutter_assets` directory, so a package's declared assets are reached
/// under the `packages/<package>/` prefix — the same convention `AssetImage`
/// uses with its `package:` argument. Anything shipped this way travels with the
/// package and needs no edit to the application's pubspec.
const String _assetRoot = 'packages/live_shell_desktop/assets/tray';

/// The Windows tray icon, as a multi-size `.ico`.
///
/// Five sizes (16, 20, 24, 32, 48) are packed as 32-bit DIB entries rather than
/// a single 32px image or PNG-compressed entries: the notification area draws at
/// 16px on a 100% display and at 32px on a 200% one, and a container holding one
/// size gets resampled by the shell — which is how a crisp mark turns into mush
/// at exactly the scaling settings where the app is most used.
const String windowsTrayIcon = '$_assetRoot/pure_live.ico';

/// The macOS menu bar icon, at 22 and 44 pixels.
const String macOSMenuIcon = '$_assetRoot/pure_live_22.png';

/// The macOS menu bar icon at retina resolution.
const String macOSMenuIconRetina = '$_assetRoot/pure_live_44.png';

/// A single-icon starting point for `TrayManagerHost.iconAssets`.
///
/// It says plainly what it is not: **one mark for every state**. The point of
/// `TrayIconState` is that `recording` must be readable at a glance in a 16-pixel
/// square, and that needs tinted artwork this package does not invent — the
/// existing launcher art was knocked out of its white background and cropped to
/// its bounds, which is derivation, not design. Drop `pure_live_recording.ico`
/// beside these and pass a fuller map to the host when that art exists; until
/// then every state shows this icon and the tooltip is the only thing that
/// changes, which the host handles by leaving the icon alone for states it has
/// no asset for.
const Map<TrayIconState, String> defaultTrayIcons = {TrayIconState.idle: windowsTrayIcon};
