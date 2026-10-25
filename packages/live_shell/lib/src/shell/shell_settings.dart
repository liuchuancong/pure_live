import 'package:live_shell/src/window_lifecycle/close_disposition.dart';

/// What the shell needs to know about the viewer's choices, as plain values.
///
/// The shell does not read a preferences package: it is handed this. That keeps
/// `live_shell` independent of how settings are stored and lets the whole
/// close/hide/reclaim behaviour be driven in a test by constructing one of
/// these, which is the point — the interesting failures here are "what the app
/// does when the button is pressed", and that must not require a settings file,
/// a display server or a tray.
final class ShellSettings {
  /// The settings for one shell.
  const new({
    this.closeAction = CloseAction.hideToTray,
    this.dontAskExit = false,
    this.trayEnabled = true,
    this.rememberBounds = true,
    this.startHidden = false,
    this.reclaimWhenIdle = false,
    this.idleReclaimAfter = const Duration(minutes: 30),
    this.idlePollInterval = const Duration(minutes: 1),
  });

  /// What the viewer wants the close button to mean.
  final CloseAction closeAction;

  /// Whether the close button performs [closeAction] without asking first.
  ///
  /// This is the reference's `dontAskExit`: when it is off, the app's
  /// [CloseChoice] callback gets the chance to confirm (and remember) the
  /// action.
  final bool dontAskExit;

  /// Whether a tray icon is wanted at all.
  ///
  /// Wanting one and *having* one are different questions — the tray can fail to
  /// appear — and the shell asks both: [ShellSettings.trayEnabled] then the
  /// host's answer.
  final bool trayEnabled;

  /// Whether the window's place is remembered between starts.
  final bool rememberBounds;

  /// Whether this start comes up without showing a window.
  final bool startHidden;

  /// Whether an idle, hidden interface may give its memory back.
  final bool reclaimWhenIdle;

  /// How long out of sight before that is considered.
  final Duration idleReclaimAfter;

  /// How often the shell asks the machine whether it has been touched.
  ///
  /// There is no portable idle event, so this is a poll, and the effective
  /// reclaim time is [idleReclaimAfter] rounded up to the next tick. One minute
  /// is the right shipping value: a finer interval buys nothing the viewer can
  /// see and wakes the process more often than the feature is worth.
  final Duration idlePollInterval;
}
