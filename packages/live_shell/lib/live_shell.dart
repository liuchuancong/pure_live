/// The desktop application shell: window chrome, close and background
/// semantics, the tray, multi-window roles, and the handoff between instances.
///
/// The rule the package is built around is that the operating system should
/// keep doing what it is good at. Windows' caption, macOS's traffic lights and
/// the window manager's snap-and-resize behaviour are not rebuilt here for
/// cosmetics: taking the frame away costs resize, Aero Snap, `Win`+arrow keys,
/// the work-area clamp that keeps a maximised window off the taskbar, the DWM
/// shadow and per-monitor DPI, and each of those then becomes a bug list of its
/// own. `ChromeStage` exists so the choice is explicit and revisitable rather
/// than accidental.
///
/// The second rule is that a decision is made once, at the moment it is true.
/// Whether closing the window ends the process is computed from the settings and
/// the tray's health *when the window is destroyed* and kept in `QuitLedger`,
/// because the "no windows left" event can arrive much later and for an
/// unrelated window. Whether a window can end the process at all is answered by
/// its `WindowRole`, never by a window count.
///
/// Nothing here talks to a plugin: `WindowHost`, `WindowLauncher`, `TrayHost`,
/// `InstanceChannel` and `StartupRegistration` are seams the application
/// implements over `window_manager`, `desktop_multi_window`, `tray_manager` and
/// the platform channels. That keeps every decision in this package a function
/// that can be tested without a display server.
library;

export 'src/instance/instance_channel.dart';
export 'src/instance/launch_intent.dart';
export 'src/instance/launch_router.dart';
export 'src/instance/socket_instance_channel.dart';
export 'src/shell/desktop_shell.dart';
export 'src/shell/shell_settings.dart';
export 'src/startup/command_startup_registration.dart';
export 'src/startup/protocol_registration.dart';
export 'src/startup/startup_registration.dart';
export 'src/tray/tray_entry.dart';
export 'src/tray/tray_host.dart';
export 'src/window_chrome/chrome_plan.dart';
export 'src/window_geometry/popup_anchor.dart';
export 'src/window_geometry/window_geometry.dart';
export 'src/window_host/window_host.dart';
export 'src/window_input/drag_throttle.dart';
export 'src/window_input/idle_watcher.dart';
export 'src/window_lifecycle/background_policy.dart';
export 'src/window_lifecycle/close_disposition.dart';
export 'src/window_lifecycle/quit_ledger.dart';
export 'src/window_opening/single_window_gate.dart';
export 'src/window_recovery/window_recovery.dart';
export 'src/window_role/window_role.dart';
export 'src/window_set/secondary_windows.dart';
export 'src/window_state/window_state_store.dart';
