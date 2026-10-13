/// How much of the interface is kept, while the app keeps running.
///
/// These are four genuinely different states, and collapsing them into
/// "visible or hidden" is what produces the two classic desktop complaints:
/// "it uses 400 MB sitting in the tray" and "it disappeared and I had to kill
/// it from Task Manager".
enum SurfaceState {
  /// The window is on screen. Everything runs.
  visible,

  /// The window is hidden but alive: instant to bring back, and playback
  /// continues without a reconnect, at the cost of keeping its surfaces.
  hidden,

  /// The window is destroyed and its rendering given back. Coming back is a
  /// rebuild — slower, and the page must be restored from what was saved — so
  /// this is only for time the viewer is demonstrably not watching.
  reclaimed,

  /// No window was ever built: a silent start that came up straight into the
  /// tray. Cheapest of all, and the state an autostart should land in.
  absent,
}

/// What the shell does about a window, given the state it is in.
enum SurfaceAction {
  /// Nothing: the window is already where the viewer asked for it.
  none,

  /// Show it, restoring from [SurfaceState.hidden].
  reveal,

  /// Rebuild it and then show it, from [SurfaceState.reclaimed] or
  /// [SurfaceState.absent].
  rebuild,

  /// Hide it, keeping everything.
  hide,

  /// Give its memory back.
  reclaim,
}

/// Decides what "bring the window back" costs, from where it currently is.
///
/// Kept separate from the window calls because the two paths are not
/// interchangeable and a UI that always calls `show()` silently does nothing
/// after a rebuild — the viewer clicks the tray icon twice before the window
/// appears, if it appears at all.
SurfaceAction resolveReveal(SurfaceState state) => switch (state) {
  SurfaceState.visible => SurfaceAction.none,
  SurfaceState.hidden => SurfaceAction.reveal,
  SurfaceState.reclaimed || SurfaceState.absent => SurfaceAction.rebuild,
};

/// Decides what "put the window away" does.
///
/// `SurfaceAction.reclaim` is only ever for a window that is already out of
/// sight: taking the
/// surface away from something on screen is not a memory optimisation, it is the
/// interface vanishing under the viewer's cursor.
SurfaceAction resolveConceal({required SurfaceState state, required bool allowReclaim}) {
  if (allowReclaim && (state == SurfaceState.hidden)) {
    return SurfaceAction.reclaim;
  }
  return state == SurfaceState.visible ? SurfaceAction.hide : SurfaceAction.none;
}

/// Whether the interface may be reclaimed because nobody has touched the
/// machine for a while.
///
/// Two gates that look interchangeable and are not:
///
/// * **[focused]** — the viewer may be sitting and reading with the mouse
///   still, which is not idleness; reclaiming a window they are looking at is a
///   visible failure. A privacy cover, by contrast, *should* fire while the
///   window is focused: that is the whole point of covering the screen when
///   someone walks up to a running machine.
/// * **[busy]** — the constraint FlowZ did not have and we do: a recording in
///   progress or a stream being pulled means the process is doing the thing the
///   viewer left it to do, and the rebuild path is where a buffer boundary or a
///   dropped segment would be found days later. Idle is not permission to
///   interfere with work.
bool shouldReclaimForIdle({
  required bool enabled,
  required bool idleThresholdReached,
  required bool focused,
  required bool busy,
  required SurfaceState state,
}) {
  if (!enabled || busy || state != SurfaceState.hidden) {
    return false;
  }
  return idleThresholdReached && !focused;
}

/// The state a process should start in.
///
/// [headless] wins over everything: a version print or a CLI subcommand must not
/// reach the display server at all, because a GUI initialisation that fails on a
/// machine with no display leaves a hung process rather than an error message —
/// and it must be decided before the single-instance lock is taken, so that a
/// `--version` run cannot be swallowed as "another instance is already up".
///
/// [restoredSession] outranks the hidden settings on purpose. Windows restarts
/// an app that was running when the machine signed out or updated, and a viewer
/// who had the app open should get the window back even if "start hidden in the
/// tray" is switched on — that setting describes how a *sign-in* start behaves,
/// not what to do with a session the operating system is handing back.
SurfaceState resolveStartState({
  required bool headless,
  required bool startHidden,
  required bool openedHiddenBySystem,
  bool restoredSession = false,
}) {
  if (headless) {
    return SurfaceState.absent;
  }
  if (restoredSession) {
    return SurfaceState.visible;
  }
  if (startHidden || openedHiddenBySystem) {
    return SurfaceState.absent;
  }
  return SurfaceState.visible;
}
