import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:window_frame_kit/window_frame_kit.dart' show WindowListener, windowManager;

export 'package:pure_uikit/pure_uikit.dart'
    show PureCaptionMetrics, PureTitleBar, PureTitleBarLabels, WindowChromeActions;

/// The seam the caption strip drives its buttons through; the app default is
/// the real window, tests hand in a recorder.
final windowChromeActionsProvider = Provider<WindowChromeActions>((ref) => const WindowManagerChromeActions());

/// The window states the caption has to follow — maximised (the glyph) and
/// full screen (the strip stands down, the video owns the window).
final class WindowChromeState {
  /// Watches the live window.
  // ignore: unnecessary_type_name_in_constructor -- a factory keeps its spelled-out name.
  factory WindowChromeState.fromWindowManager() {
    final maximised = ValueNotifier<bool>(false);
    final full = ValueNotifier<bool>(false);
    final listener = _WindowChromeListener(maximised, full);
    windowManager.addListener(listener);
    unawaited(_readInitial(maximised, full));
    return WindowChromeState._(maximised, full, listener);
  }

  /// A state nobody drives — what the tests hand the frame.
  new forTest({bool maximized = false, bool fullScreen = false})
    : this._(ValueNotifier(maximized), ValueNotifier(fullScreen), null);

  // ignore: unnecessary_type_name_in_constructor -- a private named constructor has no shorthand.
  const WindowChromeState._(this.maximized, this.fullScreen, this._listener);

  /// Whether the window is maximised — the strip swaps its glyph on this.
  final ValueNotifier<bool> maximized;

  /// Whether the window is full screen — the frame stands the strip down.
  final ValueNotifier<bool> fullScreen;

  final _WindowChromeListener? _listener;

  static Future<void> _readInitial(ValueNotifier<bool> maximised, ValueNotifier<bool> full) async {
    try {
      // The window can already be maximised or full screen when the strip
      // mounts — restored from a previous session, entered by the room.
      maximised.value = await windowManager.isMaximized();
      full.value = await windowManager.isFullScreen();
    } on Object {
      // A window manager that will not answer is a window that will not
      // change either; the strip keeps the state it started with.
    }
  }

  /// Detaches from the window and releases the notifiers.
  void dispose() {
    if (_listener != null) {
      windowManager.removeListener(_listener);
    }
    maximized.dispose();
    fullScreen.dispose();
  }
}

/// Turns the window manager's chrome events into the two notifiers.
class _WindowChromeListener extends WindowListener {
  new(this.maximized, this.fullScreen);

  final ValueNotifier<bool> maximized;
  final ValueNotifier<bool> fullScreen;

  void _set({required bool maximised, required bool full}) {
    maximized.value = maximised;
    fullScreen.value = full;
  }

  @override
  void onWindowMaximize() => _set(maximised: true, full: false);

  @override
  void onWindowUnmaximize() => _set(maximised: false, full: false);

  // Restoring a maximised window is the unmaximise path on some hosts, and
  // the strip wants the same answer whichever name the event arrives under.
  @override
  void onWindowRestore() => _set(maximised: false, full: false);

  @override
  void onWindowEnterFullScreen() => _set(maximised: false, full: true);

  @override
  void onWindowLeaveFullScreen() => _set(maximised: false, full: false);
}

/// The live window state the frame follows; tests override it with a
/// `forTest` state nobody drives.
final windowChromeStateProvider = Provider<WindowChromeState>((ref) {
  final state = WindowChromeState.fromWindowManager();
  ref.onDispose(state.dispose);
  return state;
});

/// The default actions: the plugin's facade is the only window this strip drives.
///
/// The strip itself is the core's shared [PureTitleBar]; this file keeps only
/// the windowing half of the seam, the part that cannot live in a package
/// with no windowing dependency.
final class WindowManagerChromeActions implements WindowChromeActions {
  /// The singleton instance; the class has no fields, the one fact it reads
  /// ([_dragInFlight]) belongs to the window and not to a caller.
  const new();

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> toggleMaximize() async {
    // The plugin exposes no toggle; maximise/restore is the pair.
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();

  @override
  Future<void> close() => windowManager.close();

  /// Starts the system's move loop for the window.
  ///
  /// This call is **modal**: it does not return until the pointer is released,
  /// and the engine keeps pumping frames and mouse messages while the loop runs.
  /// That is what makes a second pan start possible *inside* the first drag — the
  /// capture is released before the loop is entered, so the strip can be handed
  /// another down — and a second `SC_MOVE` re-enters the loop and re-asks the
  /// window for its non-client area. One drag is in flight at a time, and a
  /// re-entrant start is dropped rather than stacked.
  @override
  Future<void> startDragging() async {
    if (_dragInFlight) {
      return;
    }
    _dragInFlight = true;
    try {
      await windowManager.startDragging();
    } finally {
      _dragInFlight = false;
    }
  }
}

/// Whether the modal move loop is currently running for this window.
bool _dragInFlight = false;
