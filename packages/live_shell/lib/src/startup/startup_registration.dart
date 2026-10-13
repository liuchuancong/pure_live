/// Asking the operating system to start this app at sign-in.
///
/// Three platforms, three different mechanisms, and — the part that surprises
/// people — three different ways to ask for "start but stay in the tray":
/// macOS records it in its own Login Items panel rather than in the app, Linux
/// bakes a `--hidden` argument into the autostart `.desktop` file, and Windows
/// has no such option so the app decides from its own setting. So "hidden start"
/// cannot be one boolean; the interface keeps the OS's evidence separate from
/// the app's preference.
abstract interface class StartupRegistration {
  /// Turns launch-at-sign-in on or off, asking the OS for a silent start when
  /// [hidden] is set and the platform can express it.
  ///
  /// False means the OS refused — a sandboxed build cannot write the autostart
  /// entry, a managed machine forbids it. The caller must then leave the setting
  /// switch where it was: a toggle that flips on while nothing was registered is
  /// a lie the viewer only discovers at the next sign-in.
  Future<bool> setLaunchAtLogin({required bool enabled, bool hidden = false});

  /// Whether the OS will start the app, read from the OS.
  ///
  /// Not from the stored preference: on Linux the `.desktop` file is the truth
  /// and the user may edit or delete it, and a setting that disagrees with the
  /// system is worse than no setting.
  Future<bool> isLaunchAtLogin();

  /// Whether this platform can start the app without showing a window.
  bool get supportsHiddenLaunch;

  /// Whether the OS reports that it launched this process hidden — the Dock's
  /// "hide" flag on macOS, the `--hidden` argument on the others.
  ///
  /// This is what decides whether to build the window at all: a login-item start
  /// should not paint a window the viewer never asked for, and in a session with
  /// no display server creating one can wedge the process.
  bool get wasLaunchedHidden;
}

/// The command-line flag that means "come up in the tray".
///
/// Spelled in one place because three must agree: the app reading its own
/// arguments, the Windows registry value, and the Linux autostart `Exec` line.
final class LaunchHiddenFlag {
  /// The flag.
  const new();

  /// The text of the flag.
  String get value => '--hidden';
}
