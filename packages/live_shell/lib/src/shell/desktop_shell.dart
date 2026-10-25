import 'dart:async';

import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/src/shell/shell_settings.dart';
import 'package:live_shell/src/tray/tray_entry.dart';
import 'package:live_shell/src/tray/tray_host.dart';
import 'package:live_shell/src/window_geometry/window_geometry.dart';
import 'package:live_shell/src/window_host/window_host.dart';
import 'package:live_shell/src/window_input/drag_throttle.dart';
import 'package:live_shell/src/window_input/idle_watcher.dart';
import 'package:live_shell/src/window_lifecycle/background_policy.dart';
import 'package:live_shell/src/window_lifecycle/close_disposition.dart';
import 'package:live_shell/src/window_lifecycle/quit_ledger.dart';
import 'package:live_shell/src/window_recovery/window_recovery.dart';
import 'package:live_shell/src/window_role/window_role.dart';
import 'package:live_shell/src/window_set/secondary_windows.dart';
import 'package:live_shell/src/window_state/window_state_store.dart';

/// Where the primary window's pixels are right now.
///
/// A separate stream from the window manager's own events because the shell's
/// question is different: the manager reports what happened, the shell needs to
/// know what it may still do. "Hidden" and "reclaimed" both look like "not
/// visible" from the outside, and the actions that bring the window back are not
/// the same — which is exactly the difference that turns a tray click into
/// nothing at all when it is guessed wrong.
enum ShellPhase {
  /// The window is on screen.
  visible,

  /// Hidden, alive, and instantly back.
  hidden,

  /// Destroyed, and only recoverable if the app can build a new window.
  reclaimed,

  /// Never built this session.
  absent,
}

/// The piece that turns the shell's decisions into window and tray actions.
///
/// Everything above this is arithmetic — policies that answer "what should
/// happen". Everything below is a plugin, doing what it is told. This is where
/// the two meet, and the reason it is a class rather than a few lines in `main`
/// is that the meeting is where the ordering bugs live:
///
/// * **The tray's answer is read before the close policy is armed.** An icon
///   that failed to appear changes what closing means (a hidden window with no
///   way back is an unreachable process), so the shell asks [hasTray] when it
///   decides, not when the viewer saved the setting.
/// * **`closeRequested` is not `closed`.** Interception has to be armed before
///   the button is ever pressed, and a policy applied to the *already closed*
///   window can only watch the app die.
/// * **The quit intent is recorded at destruction**, and the window-count
///   question is answered from the ledger afterwards — see [QuitLedger].
///
/// One limitation worth stating plainly, because it contradicts a design the
/// shell borrows: on desktop Flutter a window destroyed through `window_manager`
/// **cannot be rebuilt from Dart** — there is no "create another primary window"
/// call. So reclaiming the interface to give memory back is available only when
/// the app itself can start a fresh window or process ([canRebuildPrimary]);
/// otherwise the shell hides and lets the app drop weight it owns (the player,
/// the decoders, the buffers), which is where the memory actually is anyway.
final class DesktopShell {
  /// A shell driving [window] on [platform].
  new({
    required this.platform,
    required this.window,
    required this.settings,
    required this.exit,
    this.confirmClose,
    this.tray,
    this.stateStore,
    this.busy = _neverBusy,
    this.rebuildWindow,
    this.idle,
    this.windows,
    this.beforeQuit,
    this.hasOtherWindows,
    this.readDisplays = _noDisplays,
    this.onMenuAction,
    this.menuEntries,
    this.iconState,
    this.tooltip,
    ReclaimCircuit? reclaim,
  }) : ledger = QuitLedger(platform: platform) {
    _drag = DragThrottle(onEnd: _dragSettled);
    _reclaim = reclaim ?? ReclaimCircuit();
  }

  /// The platform the decisions are made for.
  final PlatformKind platform;

  /// The primary window.
  final WindowHost window;

  /// Reads the current settings, fresh each time they matter: the viewer can
  /// change the close action between two presses of the same button.
  final ShellSettings Function() settings;

  /// Asks the viewer what the close button should do.
  ///
  /// Only called for the window that owns the app's lifetime, and only when
  /// [ShellSettings.dontAskExit] is off. [tray] tells the question whether a
  /// hidden window still has an icon to return from. Null cancels the close.
  final Future<CloseChoice?> Function({required bool tray})? confirmClose;

  /// One close press at a time: a second press while the question is open
  /// must not open another one.
  Future<void>? _closeFlow;

  /// Ends the process.
  final Future<void> Function() exit;

  /// The tray, when this platform has one.
  final TrayHost? tray;

  /// Where the window's place is remembered, when that is wanted.
  final WindowStateStore? stateStore;

  /// Whether something is running that the viewer left the app to do — a
  /// recording, a stream. Idle never takes the interface away from work in
  /// progress.
  final bool Function() busy;

  /// Builds a fresh primary window, for the apps that can.
  ///
  /// Its presence is the whole capability question: with `window_manager` a
  /// destroyed window cannot be shown again from Dart, so reclaiming the
  /// interface is only offered when the application knows how to make another
  /// one. A null here means the shell will hide and give memory back to the app
  /// instead of destroying anything it cannot bring back.
  final Future<void> Function()? rebuildWindow;

  /// The idle clock, if the app can read one.
  ///
  /// The shell owns the clock, not the caller: the reclaim threshold is a
  /// setting the viewer changes, and a watcher handed over already configured
  /// would fix the threshold at construction time — after which turning
  /// "reclaim after 30 minutes" down to 5 silently keeps polling at the old
  /// rate. Given a reader, the shell schedules itself and re-reads the setting
  /// through [applySettingsChanged].
  final SystemIdleReader? idle;

  /// The app's secondary windows, so the quit path can dismiss them.
  ///
  /// The reason this lives with the quit path rather than with the launcher: a
  /// panel left open on Linux and macOS keeps the process alive after the main
  /// window is gone, and the viewer's experience of that is an app that will not
  /// close — reached from the tray, the taskbar, or Task Manager, depending on
  /// how stubborn their session happens to be.
  final SecondaryWindows? windows;

  /// The app's own last step before the process ends: close engines the
  /// shell's tracked set cannot know about, flush the stores, release what
  /// lives outside the window. Runs once, before the windows are dismissed;
  /// a failure is logged by the app and must not veto the quit.
  final Future<void> Function()? beforeQuit;

  /// Whether the process still has another window besides this one.
  ///
  /// The primary's close button must not take a clone down with it: with
  /// another window alive, a plain close hides (or minimises, without a tray)
  /// instead of running the quit sequence. An explicit quit choice or the
  /// tray's quit still ends everything.
  final Future<bool> Function()? hasOtherWindows;

  /// Bounds the automatic rebuild path, so a reclaim that does not bring a window
  /// back cannot become a destroy-and-rebuild loop.
  ///
  /// Kept next to the policy rather than folded into it: the policy answers "do
  /// these inputs say reclaim?", this answers "that failed three times already",
  /// and merging them would make the decision function stateful and no longer
  /// testable by handing it inputs.
  late final ReclaimCircuit _reclaim;

  /// The displays, read when a remembered frame must be checked.
  final Future<List<DisplayFrame>> Function() readDisplays;

  /// Where a tray menu choice the shell does not already handle lands.
  ///
  /// A string id rather than a route or an intent: the shell owns show, hide and
  /// quit, and everything else belongs to the app's own menu.
  final Future<void> Function(String id)? onMenuAction;

  /// Builds the tray's menu.
  final List<TrayEntry> Function()? menuEntries;

  /// The status the icon should show.
  final TrayIconState Function()? iconState;

  /// The tooltip text.
  final String Function()? tooltip;

  /// The quit intent recorded at each destruction, consumed by the last-window
  /// question.
  final QuitLedger ledger;

  late final DragThrottle _drag;
  IdleWatcher? _watcher;
  StreamSubscription<WindowEvent>? _windowSub;
  StreamSubscription<String>? _selectionSub;
  StreamSubscription<TrayPointer>? _pointerSub;

  ShellPhase _phase = ShellPhase.absent;
  bool _quitting = false;

  /// Where the interface is now.
  ShellPhase get phase => _phase;

  /// Whether the tray icon actually exists.
  bool get hasTray => tray?.isCreated ?? false;

  /// Whether UI work may run: not while the window is being dragged.
  bool get allowsUiWork => _drag.allowsUiWork;

  /// Arms interception, subscribes to everything, and shows or withholds the
  /// window according to how this process was started.
  ///
  /// The order is not arbitrary: the tray is created *first* because the close
  /// policy needs to know whether it succeeded, and interception is armed
  /// *before* the window is shown because the first close request can otherwise
  /// arrive while the shell is still unsubscribed.
  Future<void> start({bool openedHiddenBySystem = false, bool restoredSession = false}) async {
    await _attachTray();
    _subscribeWindow();
    await window.setPreventClose(enabled: true);
    stateStore?.resume();
    // Applied before the visibility decision so the window appears where it was
    // rather than appearing and then jumping. (A maximised state is *not* reliably
    // restored this way — that case is still open; see the note on
    // [restoreGeometry].)
    await restoreGeometry();
    final state = resolveStartState(
      headless: false,
      startHidden: settings().startHidden,
      openedHiddenBySystem: openedHiddenBySystem,
      restoredSession: restoredSession,
    );
    if (state == SurfaceState.visible) {
      await reveal();
    } else {
      // Hiding is not the same as declining to show. On Windows and Linux the
      // runner has already mapped and shown the window before Dart's entry point
      // runs, so a shell that only withholds its own `show()` leaves the window
      // on screen and "start hidden" is a setting that silently does nothing.
      await window.hide();
      _phase = ShellPhase.hidden;
    }
    _scheduleIdle();
    await refreshTray();
  }

  /// (Re)starts the idle clock at the threshold currently configured.
  ///
  /// No clock at all when the setting is off: a poll that wakes the process
  /// every minute to ask a question whose answer is then discarded is a cost
  /// paid for a feature nobody turned on.
  void _scheduleIdle() {
    final reader = idle;
    _watcher?.stop();
    if (reader == null || !settings().reclaimWhenIdle) {
      _watcher = null;
      return;
    }
    _watcher = IdleWatcher(
      read: reader,
      threshold: settings().idleReclaimAfter,
      interval: settings().idlePollInterval,
      onIdle: (_) => unawaited(noteIdle(idleLongEnough: true)),
    )..start();
  }

  /// Re-reads everything that was scheduled from the settings.
  ///
  /// Called by the app after it saves a change to the desktop group; without it
  /// the polling interval and the reclaim threshold would stay whatever they were
  /// at start-up, and the viewer would be editing a control that took effect
  /// only after a restart — which is worth saying out loud for the settings that
  /// genuinely do need one, and worth not lying about for these.
  Future<void> applySettingsChanged() async {
    _scheduleIdle();
    await refreshTray();
  }

  /// Brings the window back from wherever it is.
  Future<void> reveal() async {
    final action = resolveReveal(_asSurface(_phase));
    switch (action) {
      case SurfaceAction.none:
      case SurfaceAction.hide:
      case SurfaceAction.reclaim:
        return;
      case SurfaceAction.reveal:
        await window.show(inactive: !window.role.takesFocusOnShow);
        _phase = ShellPhase.visible;
      case SurfaceAction.rebuild:
        // Two different states ask for this. Never shown this session means the
        // window exists and simply needs raising; destroyed means nothing this
        // shell can say will bring it back, and the only honest answer is to ask
        // the application — or, if it cannot, leave the phase alone rather than
        // pretending the click did something.
        if (_phase == ShellPhase.absent) {
          await window.show(inactive: !window.role.takesFocusOnShow);
          _phase = ShellPhase.visible;
        } else {
          final rebuild = rebuildWindow;
          if (rebuild == null) {
            return;
          }
          await _attemptRebuild(rebuild);
        }
    }
    if (_phase == ShellPhase.visible) {
      stateStore?.resume();
      _watcher?.noteActivity();
    }
    await refreshTray();
  }

  /// Rebuilds the primary window, counting a rebuild that threw as a failure.
  ///
  /// The observable signal is only whether [rebuildWindow] completed: after a
  /// destroy, the handle this shell holds refers to the window that is gone — the
  /// replacement is a different host in a different engine, which this class has
  /// no reference to and no way to interrogate. So a rebuild that returns
  /// normally but never produces a usable window is not something the shell can
  /// detect, and pretending otherwise (by asking the dead handle whether it is
  /// alive, which answers no forever) would trip the circuit on every single
  /// reclaim. What is bounded is the loop a throwing rebuild would cause:
  /// destroy, rebuild, throw, destroy, rebuild — the failure that eats a machine.
  Future<void> _attemptRebuild(Future<void> Function() rebuild) async {
    final now = DateTime.now();
    try {
      await rebuild();
    } on Object {
      _reclaim.recordFailure(now);
      // The window is still whatever the failed attempt left behind, which is not
      // "visible": leaving the phase alone here would let the shell believe its
      // own optimistic claim and start saving a frame for a window that is gone.
      _phase = ShellPhase.reclaimed;
      rethrow;
    }
    _reclaim.noteRecovered();
    _phase = ShellPhase.visible;
  }

  /// Puts the window away, as the settings ask.
  ///
  /// Called for the tray's "hide" item and for any leave-that-hides; the close
  /// button goes through [handleClose] instead, because that one needs the
  /// platform and tray rules applied.
  Future<void> conceal() async {
    final action = resolveConceal(
      state: _asSurface(_phase),
      allowReclaim: canRebuildPrimary && settings().reclaimWhenIdle && !busy(),
    );
    // Before whichever way this leaves the screen: the store is paused on hide
    // and the window is gone after a reclaim, so this is the last reading either
    // branch will get.
    await _record();
    switch (action) {
      case SurfaceAction.hide:
        await window.hide();
        _phase = ShellPhase.hidden;
        stateStore?.pause();
      case SurfaceAction.reclaim:
        ledger.record(trigger: QuitTrigger.lightweightMode, minimizeToTray: true, hasTray: hasTray);
        await window.destroy();
        _phase = ShellPhase.reclaimed;
        stateStore?.pause();
      case SurfaceAction.none:
      case SurfaceAction.reveal:
      case SurfaceAction.rebuild:
        return;
    }
    await refreshTray();
  }

  /// Applies the close policy to a press of the close button.
  Future<void> handleClose() => _closeFlow ??= _handleClose().whenComplete(() => _closeFlow = null);

  Future<void> _handleClose() async {
    final current = settings();
    var action = current.closeAction;
    var explicitQuit = false;
    final ask = confirmClose;
    // The reference asks before closing the window that owns the app, and
    // stores the answer so the next press can skip the question.
    if (ask != null && !current.dontAskExit && !_quitting && window.role.ownsAppState) {
      final choice = await ask(tray: hasTray);
      if (choice == null) return;
      action = choice.action;
      explicitQuit = action == CloseAction.quit;
    }
    var disposition = resolveCloseDisposition(
      platform: platform,
      action: action,
      role: window.role,
      hasTray: hasTray,
      isQuitting: _quitting,
    );
    // A plain close of the primary is a window close, not an app quit, when
    // another window still exists. The app keeps its engine and database; the
    // tray (or a remaining clone) is the way back. An explicit Quit choice
    // bypasses this, as does the tray's Quit.
    if (disposition == CloseDisposition.quit && !explicitQuit) {
      final probe = hasOtherWindows;
      if (probe != null) {
        var others = false;
        try {
          others = await probe();
        } on Object {
          // An unanswerable probe falls back to the ordinary quit.
        }
        if (others) {
          disposition = hasTray ? CloseDisposition.hide : CloseDisposition.minimise;
        }
      }
    }
    switch (disposition) {
      case CloseDisposition.hide:
        // Last chance to capture where the window actually is: hiding stops the
        // store, and a programmatic move or snap may never have produced an event
        // for us to record from.
        await _record();
        await window.hide();
        _phase = ShellPhase.hidden;
        stateStore?.pause();
      case CloseDisposition.minimise:
        await window.minimize();
      case CloseDisposition.destroy:
        ledger.record(
          trigger: QuitTrigger.windowClose,
          minimizeToTray: action == CloseAction.hideToTray,
          hasTray: hasTray,
        );
        await _record();
        await window.destroy();
        // Reclaimed, not absent: the window existed and no longer does, which is
        // a different question from never having been built — raising the latter
        // is a call, the former needs a rebuild.
        _phase = ShellPhase.reclaimed;
        stateStore?.pause();
      case CloseDisposition.quit:
        await prepareToQuit();
        await window.close();
        await exit();
    }
    await refreshTray();
  }

  /// Called when the window count has reached zero.
  ///
  /// Answers from the ledger rather than from the settings on screen now: the
  /// decision belonged to the moment the window was destroyed, and by this point
  /// anything may have happened in between.
  Future<void> handleLastWindowClosed() async {
    if (ledger.consumeOnLastWindowClosed()) {
      await prepareToQuit();
      await exit();
    }
  }

  /// Records how long the machine has been untouched and reclaims if that means
  /// something.
  Future<void> noteIdle({required bool idleLongEnough}) async {
    // A manual request to come back is never refused, so the limiter is checked
    // here and not in `resolveReveal`: this is the path that runs on its own.
    if (_reclaim.isTripped(DateTime.now())) {
      return;
    }
    if (!shouldReclaimForIdle(
      enabled: settings().reclaimWhenIdle && canRebuildPrimary,
      idleThresholdReached: idleLongEnough,
      focused: (await window.snapshot()).isFocused,
      busy: busy(),
      state: _asSurface(_phase),
    )) {
      return;
    }
    ledger.record(trigger: QuitTrigger.memoryWatchdog, minimizeToTray: true, hasTray: hasTray);
    await window.destroy();
    _phase = ShellPhase.reclaimed;
    stateStore?.pause();
  }

  /// Rebuilds the tray's icon and menu from what the app says they should be.
  Future<void> refreshTray() async {
    final host = tray;
    if (host == null || !host.isCreated) {
      return;
    }
    final state = iconState?.call();
    if (state != null) {
      await host.setIcon(state);
    }
    final tip = tooltip?.call();
    if (tip != null) {
      await host.setTooltip(tip);
    }
    final entries = menuEntries?.call();
    if (entries != null) {
      await host.setMenu(entries);
    }
  }

  /// Reads back the remembered place, if remembering is wanted.
  ///
  /// The maximised half of this depends on the Windows runner: the window is
  /// maximised here during start-up, and `Win32Window::Show()` — which the runner
  /// calls from its first-frame callback, i.e. after this — must use `SW_SHOW`, not
  /// `SW_SHOWNORMAL`, because the latter also *restores* a maximised window.
  /// Measured on a real build: with `SW_SHOWNORMAL` the window reads as maximised
  /// at start-up and not maximised one second later; with `SW_SHOW` it stays.
  /// Nothing in this package can defend against that, so if the runner is ever
  /// regenerated from the Flutter template, check that call.
  Future<void> restoreGeometry() async {
    final store = stateStore;
    if (store == null || !settings().rememberBounds) {
      return;
    }
    final remembered = await store.restore(await readDisplays());
    if (remembered != null) {
      await window.setGeometry(remembered);
    }
  }

  /// The sequence every exit goes through, whoever asked for it.
  ///
  /// Flush first and destroy the tray icon second: a debounced geometry write
  /// lost to process exit is a window in the wrong place tomorrow, and an icon
  /// left behind outlives its process only until the shell notices, which the
  /// viewer notices first.
  Future<void> prepareToQuit() async {
    if (_quitting) {
      return;
    }
    _quitting = true;
    _watcher?.stop();
    // The app gets the first word: engines that only it can address, then
    // any store buffers, before the window set below starts closing.
    final hook = beforeQuit;
    if (hook != null) {
      try {
        await hook();
      } on Object {
        // A failed last step must not turn quit into a window that stays.
      }
    }
    ledger.record(trigger: QuitTrigger.explicitQuit, minimizeToTray: false, hasTray: hasTray);
    await windows?.dismissAll();
    await _record();
    await stateStore?.flush();
    await _windowSub?.cancel();
    await _selectionSub?.cancel();
    await _pointerSub?.cancel();
    await tray?.dispose();
  }

  /// Whether the interface can be destroyed and rebuilt again.
  bool get canRebuildPrimary => rebuildWindow != null;

  /// Releases the shell's subscriptions without touching the process.
  Future<void> dispose() async {
    _watcher?.stop();
    _drag.dispose();
    await _windowSub?.cancel();
    await _selectionSub?.cancel();
    await _pointerSub?.cancel();
  }

  Future<void> _attachTray() async {
    final host = tray;
    if (host == null || !settings().trayEnabled) {
      return;
    }
    await host.create();
    if (!host.isCreated) {
      return;
    }
    _selectionSub = host.selections.listen(handleSelection);
    _pointerSub = host.pointers.listen(handlePointer);
  }

  /// Handles a click on the icon, with the conventions the platforms actually
  /// use: on Windows and Linux the primary button brings the window back and the
  /// secondary opens the menu; on macOS the menu carries both, because clicking
  /// a menu bar item is how you get its menu, and a click that also raised a
  /// window would make the menu impossible to read.
  Future<void> handlePointer(TrayPointer pointer) async {
    if (platform == PlatformKind.macos) {
      return;
    }
    if (pointer == TrayPointer.click) {
      await reveal();
    }
  }

  /// Routes a chosen menu entry.
  Future<void> handleSelection(String id) async {
    switch (id) {
      case 'show':
        await reveal();
      case 'hide':
        await conceal();
      case 'quit':
        await prepareToQuit();
        await window.close();
        await exit();
      default:
        await onMenuAction?.call(id);
    }
  }

  void _subscribeWindow() {
    _windowSub = window.events.listen((event) {
      switch (event) {
        case WindowEvent.closeRequested:
          unawaited(handleClose());
        case WindowEvent.hidden:
          _phase = ShellPhase.hidden;
          stateStore?.pause();
        case WindowEvent.closed:
          _phase = ShellPhase.reclaimed;
          stateStore?.pause();
        case WindowEvent.restored:
          _phase = ShellPhase.visible;
        case WindowEvent.moved:
          _drag.noteMoved();
          unawaited(_record());
        case WindowEvent.resized:
          unawaited(_record());
        case WindowEvent.focused:
        case WindowEvent.blurred:
        case WindowEvent.maximised:
        case WindowEvent.unmaximised:
          // Remembered the moment it is heard, and not only from the button:
          // the frame and the maximised flag are stored as a pair, and the most
          // common way to maximise a window on Windows is the keyboard or a snap
          // edge, which the platform may report late or not at all.
          unawaited(_record());
        case WindowEvent.minimised:
        case WindowEvent.enteredFullScreen:
        case WindowEvent.leftFullScreen:
        case WindowEvent.snapped:
        case WindowEvent.unsnapped:
        case WindowEvent.interrupted:
        case WindowEvent.resumed:
          break;
      }
    });
  }

  Future<void> _record() async {
    final store = stateStore;
    if (store == null || !settings().rememberBounds) {
      return;
    }
    store.note(await window.geometry());
  }

  void _dragSettled() {
    // The frame the drag skipped is worth one more write: the window is now
    // where it ended up, and that is the place to remember.
    unawaited(_record());
  }

  SurfaceState _asSurface(ShellPhase phase) => switch (phase) {
    ShellPhase.visible => SurfaceState.visible,
    ShellPhase.hidden => SurfaceState.hidden,
    ShellPhase.reclaimed => SurfaceState.reclaimed,
    ShellPhase.absent => SurfaceState.absent,
  };
}

bool _neverBusy() => false;

Future<List<DisplayFrame>> _noDisplays() async => const [];
