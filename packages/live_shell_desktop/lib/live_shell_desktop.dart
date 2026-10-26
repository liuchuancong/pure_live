/// The desktop implementation of `live_shell`'s seams.
///
/// `live_shell` decides what a window should do — what closing means, whether
/// the tray came up, where the window was last seen, which launch request came
/// from a second instance. This package answers the part where something has to
/// be asked of the operating system, over `multiview_desktop` (every window is
/// a view in this one engine), `tray_manager` (the notification area) and
/// `screen_retriever` (the displays).
///
/// The split is deliberate: a package that depends on plugins cannot be tested
/// without a desktop session, and the decisions worth testing are exactly the
/// ones that must not need one.
library;

export 'src/configure_main_window.dart';
export 'src/desktop_notifications.dart';
export 'src/displays.dart';
export 'src/multiview/desktop_message_bus.dart';
export 'src/multiview/desktop_window_registry.dart';
export 'src/multiview/multi_view_window_host.dart';
export 'src/multiview/multi_view_window_launcher.dart';
export 'src/system_idle.dart';
export 'src/tray_manager_host.dart';
export 'src/window_manager_host.dart';
export 'src/window_material.dart';
export 'src/windows_accent_color.dart' show readWindowsAccentColor;
export 'src/windows_version.dart' show kWindowsRoundedFrameBuild, windowsBuildNumber;
