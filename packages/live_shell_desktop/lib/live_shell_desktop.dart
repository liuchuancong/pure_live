/// The desktop implementation of `live_shell`'s seams.
///
/// `live_shell` decides what a window should do — what closing means, whether
/// the tray came up, where the window was last seen, which launch request came
/// from a second instance. This package answers the part where something has to
/// be asked of the operating system, over `window_manager` (the current engine's
/// window), `tray_manager` (the notification area), `screen_retriever` (the
/// displays) and `desktop_multi_window` (windows in other engines).
///
/// The split is deliberate: a package that depends on plugins cannot be tested
/// without a desktop session, and the decisions worth testing are exactly the
/// ones that must not need one.
library;

export 'src/configure_main_window.dart';
export 'src/desktop_window_launcher.dart';
export 'src/displays.dart';
export 'src/system_idle.dart';
export 'src/tray_manager_host.dart';
export 'src/window_manager_host.dart';
export 'src/window_material.dart';
export 'src/windows_version.dart' show kWindowsRoundedFrameBuild, windowsBuildNumber, windowsDrawsFrameEdgeItself;
