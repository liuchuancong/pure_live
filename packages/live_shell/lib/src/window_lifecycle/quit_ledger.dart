import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/src/window_lifecycle/close_disposition.dart';

/// Why a window is about to disappear.
enum QuitTrigger {
  /// The viewer pressed the close button.
  windowClose,

  /// Lightweight mode reclaimed the window's memory while the session runs on.
  lightweightMode,

  /// The memory watchdog decided the hidden window was costing too much.
  memoryWatchdog,

  /// The viewer chose Quit.
  explicitQuit,
}

/// The last destruction's quit intent, kept until the window-count event needs it.
///
/// Why this exists at all: "should the app quit now?" cannot be answered when
/// the last-window-closed event arrives. By then the question has already been
/// overtaken by events — if a cast panel or an update popup was still open, the
/// main window's destruction did not raise the event at all, and the event
/// eventually fires at a moment unrelated to anything the viewer did, where
/// re-reading the settings answers a different question than the one that was
/// asked. So the decision is made once, in the instant a window is destroyed,
/// and this ledger is what the later event reads.
///
/// The same reason rules out a one-shot flag: while the count is still non-zero
/// the flag sits around dirty, and an unrelated window closing later reads it
/// as if it were fresh.
final class QuitLedger {
  /// A ledger with no pending intent, which behaves as the platform expects.
  new({required this.platform});

  /// The platform the decisions are made for.
  final PlatformKind platform;

  bool? _pending;

  /// Whether an intent is recorded but unconsumed — the window count is still
  /// non-zero because a secondary window is open.
  bool get hasPending => _pending != null;

  /// The recorded intent, without consuming it.
  bool? get peek => _pending;

  /// Records the intent implied by destroying the main window [trigger]ed this
  /// way, with the settings and tray state that were in force at that moment.
  void record({required QuitTrigger trigger, required bool minimizeToTray, required bool hasTray}) {
    _pending = switch (trigger) {
      // An explicit quit needs no window count to end the process.
      QuitTrigger.explicitQuit => true,
      // Lightweight mode keeps the session running by contract — a recording
      // must not stop because the interface gave its memory back. It is
      // therefore evaluated as "hide to tray", with the tray's own failure to
      // appear still able to force a quit.
      QuitTrigger.lightweightMode || QuitTrigger.memoryWatchdog => shouldQuitOnAllWindowsClosed(
        platform: platform,
        minimizeToTray: true,
        hasTray: hasTray,
      ),
      QuitTrigger.windowClose => shouldQuitOnAllWindowsClosed(
        platform: platform,
        minimizeToTray: minimizeToTray,
        hasTray: hasTray,
      ),
    };
  }

  /// Clears the recorded intent; used when the window comes back so a later
  /// unrelated close cannot be answered with the stale decision.
  void clear() => _pending = null;

  /// Answers the last-window-closed event and consumes the intent.
  ///
  /// With nothing recorded the platform's own convention applies: a Mac keeps
  /// running, everywhere else the process ends.
  bool consumeOnLastWindowClosed() {
    final pending = _pending;
    _pending = null;
    return pending ?? shouldQuitOnAllWindowsClosed(platform: platform, minimizeToTray: false, hasTray: true);
  }
}
