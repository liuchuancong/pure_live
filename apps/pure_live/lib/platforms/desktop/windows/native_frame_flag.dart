import 'dart:io';

import 'package:live_shell_desktop/live_shell_desktop.dart' show windowsDrawsFrameEdgeItself;
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart' show ShellWindowChrome;

/// How the Windows runner is told who owns the window frame.
///
/// ## Why a file, when the app has both a preference store and launch arguments
///
/// * **The store is unreadable from C++.** The preference lives in a Hive box
///   (`settings.preferences` / `preferences.shell.v1`). `wWinMain` would need a
///   Hive reader to see it, which is not a thing to put in a runner.
/// * **A launch argument cannot be aimed at yourself.** `--hidden` works because
///   something *else* puts it on the command line — the autostart Exec entry, a
///   protocol handler, the user. `Restart.restartApp()` re-execs the command line
///   the process already has, so a setting changed inside the app can never reach
///   the next process that way.
/// * **It has to survive a plain double-click.** A `--native-frame` flag only
///   helps a launch that carries it; the setting has to work for the window
///   opened from the Start menu.
///
/// So an explicit choice is mirrored into one small file in the user's profile —
/// the same directory the single-instance nonce uses (`USERPROFILE`, falling back
/// to `HOME`), which adds no new path coupling.
///
/// ## Absent means "not chosen", and that is the interesting case
///
/// The file is written **only when the viewer actually changes the setting**. A
/// never-touched install has no file, and then the mode comes from the operating
/// system: Windows 11 draws a window's rounded corners and frame edge itself, so
/// an app that takes the non-client area over still looks like a window, and the
/// self-drawn strip is the default. Windows 10 does neither — a custom frame
/// there leaves a square-cornered rectangle with no visible edge against the
/// desktop — so the native caption is the default.
///
/// Keeping that decision *derived* rather than recorded is what makes it survive
/// a Windows 10 to 11 upgrade: nothing pinned the answer on the first start, so
/// the next start simply asks the OS again.
///
/// ## Precedence, which both sides must apply identically
///
/// 1. `--native-frame` / `--custom-frame` on the command line (last one wins).
/// 2. The flag file, when it names a mode.
/// 3. The operating system's default, from [windowsDrawsFrameEdgeItself].
///
/// `main.cpp`'s `UseNativeWindowFrame()` implements the same three steps. They
/// cannot be consolidated — one runs before this isolate exists — so a change
/// here must be mirrored there, or the window gets a native frame the app
/// believes it drew itself, which is the single failure mode this file exists to
/// prevent.
abstract final class NativeFrameFlag {
  /// The file's name, in the user's profile directory.
  static const String fileName = '.pure_window_chrome';

  /// The flag file, or null when no profile directory can be found.
  static File? file() {
    final profile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (profile == null || profile.isEmpty) {
      return null;
    }
    return File('$profile${Platform.pathSeparator}$fileName');
  }

  /// The mode the file names, or null when it is absent, unreadable or holds
  /// something that is not a mode.
  ///
  /// Null is not an error and not a default — it means "no explicit choice",
  /// which the caller answers from the operating system. Never thrown: a settings
  /// file must not be able to stop the app from starting.
  static ShellWindowChrome? read() {
    final target = file();
    if (target == null || !target.existsSync()) {
      return null;
    }
    try {
      return parse(target.readAsStringSync());
    } on FileSystemException {
      return null;
    }
  }

  /// The mode [raw] names, or null.
  ///
  /// Trimmed and lower-cased because the file is written by us but sits where a
  /// person can open it in Notepad and type something. Anything that is not
  /// exactly one of the two identifiers counts as absent, so a corrupt file
  /// cannot conjure a mode — it just stops being an override.
  static ShellWindowChrome? parse(String raw) {
    final id = raw.trim().toLowerCase();
    return switch (id) {
      'app' => ShellWindowChrome.app,
      'system' => ShellWindowChrome.system,
      _ => null,
    };
  }

  /// The frame mode this process runs in, following the precedence above.
  ///
  /// Call it once, at start-up, and keep the answer for the life of the process:
  /// the frame is taken or left before the first frame is painted, so re-reading
  /// mid-run reports a mode the live window is not in.
  static ShellWindowChrome resolve({required List<String> args}) {
    for (final argument in args.where((value) => value.startsWith('--')).toList(growable: false).reversed) {
      switch (argument) {
        case '--native-frame':
          return ShellWindowChrome.system;
        case '--custom-frame':
          return ShellWindowChrome.app;
      }
    }
    return read() ?? defaultWindowChrome();
  }

  /// The mode for a viewer who never picked one.
  static ShellWindowChrome defaultWindowChrome() =>
      windowsDrawsFrameEdgeItself() ? ShellWindowChrome.app : ShellWindowChrome.system;

  /// Mirrors an explicit choice, so the next start takes that frame.
  ///
  /// Returns whether the write landed. Failure is not fatal — the app still
  /// starts, in whatever the file already said — but it must be reported: a
  /// silently unwritten flag means the setting appears to do nothing, which is
  /// the exact thing this file exists to prevent.
  static Future<bool> write(ShellWindowChrome chrome) async {
    final target = file();
    if (target == null) {
      return false;
    }
    try {
      await target.writeAsString(chrome.id, flush: true);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Drops the override, returning the choice to the operating system's default.
  static Future<bool> clear() async {
    final target = file();
    if (target == null) {
      return false;
    }
    try {
      if (target.existsSync()) {
        await target.delete();
      }
      return true;
    } on FileSystemException {
      return false;
    }
  }
}
