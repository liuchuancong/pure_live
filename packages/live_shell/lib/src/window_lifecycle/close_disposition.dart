import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/src/window_role/window_role.dart';

/// What the viewer asked the close button to mean.
///
/// Three values rather than one switch, because a single "minimize to tray"
/// boolean is made to carry three different things at once — hide but keep the
/// process, minimise to the taskbar, and actually quit — and on macOS two of
/// them are not available at all. The setting is a preference; what it means
/// after the platform and the tray's health are taken into account is
/// [resolveCloseDisposition].
enum CloseAction {
  /// Take the window away, keep everything behind it, show it again instantly.
  hideToTray,

  /// Minimise to the taskbar: still a window, just not on screen.
  minimise,

  /// Close for good; with no other window left this ends the process.
  quit,
}

/// The viewer's answer to a close confirmation: what to do, and whether the
/// question should stop being asked.
typedef CloseChoice = ({CloseAction action, bool remember});

/// What the shell does with the window, once the platform and the tray's
/// condition have had their say.
enum CloseDisposition {
  /// Hide the window. Process and renderer stay warm, so the window returns
  /// with no rebuild and no lost playback.
  hide,

  /// Minimise: the window survives, the taskbar keeps its button.
  minimise,

  /// Destroy the window and its rendering surface, keep the process alive.
  /// This is macOS's "closed but still running" and the shell's own
  /// lightweight mode, which exists to give memory back while a recording
  /// continues.
  destroy,

  /// Let the close happen, and let the app end with it.
  quit,
}

/// Decides what closing [role]'s window does.
///
/// Three rules are load-bearing and each has a reason:
///
/// * **[platform] macOS never quits here.** Closing the last window keeps a Mac
///   app running with a Dock icon, and the viewer expects to bring it back by
///   clicking that icon; the setting is not offered on macOS at all.
/// * **Only [WindowRole.main] can end the process.** A floating video window is
///   a second view of a session the main window owns; destroying the view must
///   not take the session — or the app — with it.
/// * **A broken tray falls back to quitting.** `TrayHost.create()` can fail and
///   callers commonly swallow it: an unavailable notification area on Linux, a
///   full one on Windows. Hiding a window with no icon left to bring it back
///   produces a process with no window and no way to reach it, which the viewer
///   will describe as a hang. So `hasTray` is an input, not an afterthought.
CloseDisposition resolveCloseDisposition({
  required PlatformKind platform,
  required CloseAction action,
  required WindowRole role,
  required bool hasTray,
  bool isQuitting = false,
}) {
  // A quit already in progress: no interception, the default close is correct.
  if (isQuitting) {
    return CloseDisposition.quit;
  }
  if (!role.ownsAppState) {
    // A secondary window's close is only ever about that window.
    return CloseDisposition.destroy;
  }
  // An explicit quit is honoured on every platform, macOS included: the rule
  // that a closed window does not end a Mac app is about hiding and closing,
  // not about overruling a viewer who chose Quit.
  if (action == CloseAction.quit) {
    return CloseDisposition.quit;
  }
  if (platform == PlatformKind.macos) {
    // The window goes, the app stays; `activate` rebuilds it. The setting's
    // other two meanings are not offered on macOS at all.
    return CloseDisposition.destroy;
  }
  return switch (action) {
    CloseAction.quit => CloseDisposition.quit,
    CloseAction.minimise => CloseDisposition.minimise,
    CloseAction.hideToTray => hasTray ? CloseDisposition.hide : CloseDisposition.quit,
  };
}

/// Whether the process should end when no window is left.
///
/// The same pure function serves the plain "last window closed" event and the
/// lightweight-mode teardown, so the two cannot drift apart.
bool shouldQuitOnAllWindowsClosed({
  required PlatformKind platform,
  required bool minimizeToTray,
  required bool hasTray,
}) {
  if (platform == PlatformKind.macos) {
    return false;
  }
  return !minimizeToTray || !hasTray;
}
