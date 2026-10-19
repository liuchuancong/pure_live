import 'package:live_shell/src/window_geometry/window_geometry.dart';
import 'package:live_shell/src/window_role/window_role.dart';

/// A notification that something happened to a window.
enum WindowEvent {
  /// The window was hidden without being destroyed; a re-show is cheap.
  hidden,

  /// The viewer asked the window to close, and the shell has been given the
  /// decision instead of the window manager.
  ///
  /// Emitted only when close interception is armed. It is deliberately not the
  /// same event as [closed]: hiding the window to the tray also ends up going
  /// through the close path, and a shell that treats the request as an already
  /// completed close hides nothing and loses the window on the first press of
  /// the wrong button.
  closeRequested,

  /// The window was closed, or destroyed for memory. Nothing further may be
  /// asked of the host after this.
  closed,

  /// The window became the focused window.
  focused,

  /// The window stopped being the focused window.
  blurred,

  /// The window's position changed.
  ///
  /// This is also the signal the drag throttle watches: while these arrive, no
  /// non-essential UI work should be scheduled.
  moved,

  /// The window's size changed.
  resized,

  /// The window was minimised to the taskbar.
  minimised,

  /// The window came back from being minimised.
  restored,

  /// The window became maximised, by whatever route.
  ///
  /// The state arrives as an event rather than being remembered from a button
  /// press: the viewer can also double-click the strip, drag the window to the
  /// top edge or press `Win`+up, and the window manager can maximise it on its
  /// own. A caption icon driven only by clicks disagrees with the real window
  /// within seconds.
  maximised,

  /// The window stopped being maximised.
  unmaximised,

  /// Fullscreen started.
  enteredFullScreen,

  /// Fullscreen ended, including the OS's own gesture on macOS.
  leftFullScreen,

  /// The window was docked to an edge or into a snap layout slot.
  snapped,

  /// The window left the docked or snapped state.
  unsnapped,

  /// The session was interrupted: the screen locked, the machine slept, or the
  /// viewer switched away. A player should pause; a recorder usually should not.
  interrupted,

  /// The session came back.
  resumed,
}

/// One window the shell controls.
///
/// The application implements this over `window_frame_kit` (main window) or
/// `desktop_multi_window` (secondary ones); everything in `live_shell` decides
/// behaviour against this interface instead of against a plugin, which is what
/// lets the policy code be tested without a display server.
abstract interface class WindowHost {
  /// What this window is for.
  WindowRole get role;

  /// Whether the native window still exists.
  bool get isAlive;

  /// Everything the window manager tells us about it.
  Stream<WindowEvent> get events;

  /// Shows the window.
  ///
  /// [inactive] presents it without taking keyboard focus — what a corner popup
  /// needs, and the difference between a toast and an interruption.
  Future<void> show({bool inactive = false});

  /// Hides the window, keeping its process and rendering surface.
  Future<void> hide();

  /// Minimises to the taskbar.
  Future<void> minimize();

  /// Restores from minimised or from maximised, whichever applies.
  Future<void> restore();

  /// Toggles maximised and answers the state that resulted.
  ///
  /// Returning the new value is not a convenience: reading it back afterwards
  /// races the window manager, and a caption icon that shows the state from
  /// before the toggle is worse than one that waits.
  Future<bool> toggleMaximize();

  /// Whether the window is currently maximised, as the OS knows it.
  Future<bool> isMaximized();

  /// Arms or disarms the interception that produces [WindowEvent.closeRequested].
  ///
  /// Without it the window manager closes the window the moment the button is
  /// pressed and there is nothing left to decide: a viewer with "minimise to
  /// tray" set gets their session killed by a click they meant as a hide.
  Future<void> setPreventClose({required bool enabled});

  /// Asks the window to close, going through whatever the platform's close
  /// interception does — the disposition from `resolveCloseDisposition` is
  /// applied by the caller that owns the policy, not by this method.
  Future<void> close();

  /// Destroys the window and its surface without ending the process. This is
  /// lightweight mode: memory back, state kept by the app, rebuildable.
  Future<void> destroy();

  /// The window's current frame and maximised state.
  Future<WindowGeometry> geometry();

  /// Places and sizes the window.
  Future<void> setGeometry(WindowGeometry geometry);

  /// Centers the window on the display it is currently on.
  Future<void> center();

  /// Puts the window above all others, used by the floating video window.
  Future<void> setAlwaysOnTop({required bool value});

  /// Lets or stops letting the window be resized by its edges.
  Future<void> setResizable({required bool value});

  /// Sets the title the taskbar and window list show.
  Future<void> setTitle(String value);

  /// Reports the current state after a caller has changed something, so the
  /// shell can reconcile its own view with the window manager's.
  Future<WindowState> snapshot();
}

/// A window's reported state, gathered in one round trip.
final class WindowState {
  /// A state.
  const new({required this.geometry, required this.isVisible, required this.isFocused, this.scaleFactor = 1});

  /// Where it is, and whether it is maximised.
  final WindowGeometry geometry;

  /// Whether the window is on screen.
  final bool isVisible;

  /// Whether it is the focused window.
  final bool isFocused;

  /// The device pixel ratio the window is being drawn at.
  final double scaleFactor;
}

/// Creates additional OS-level windows.
///
/// The seam exists because a second window on the desktop is a second engine,
/// not a widget: with `desktop_multi_window` each one is its own isolate with its
/// own Dart heap, so the rules that follow from that belong to the shell and not
/// to a call site —
///
/// * the new window cannot share the main window's in-memory state, only its
///   persisted state and messages sent through the launcher;
/// * it must be told its [WindowRole] at creation, because it cannot ask;
/// * closing it is never an app-level event, which is why the role, not a
///   window count, decides what a close means.
abstract interface class WindowLauncher {
  /// Opens a window of [role], starting at [route] where the role has one.
  ///
  /// The answer is a [SecondaryWindow], not a [WindowHost]: from the primary's
  /// side a window belonging to another engine can be raised, lowered and sent
  /// messages, but not measured or moved — its geometry belongs to its own
  /// isolate, which is the one holding the surface. A caller that needs the
  /// window sized should pass the size in as part of [route]/launch arguments
  /// and let the new window apply it, rather than reaching for it afterwards.
  Future<SecondaryWindow> open({required WindowRole role, String? route});
}

/// A window in another engine, reachable only by message.
abstract interface class SecondaryWindow {
  /// The id the window manager gave this window.
  String get id;

  /// What it was created for, as handed to it at creation.
  WindowRole get role;

  /// Brings it on screen.
  ///
  /// Addressed by window id through the native layer, so this works as soon as
  /// the window exists — it does not wait for the other isolate to be listening.
  Future<void> show();

  /// Hides it, keeping the engine alive.
  ///
  /// Native, like [show]. There is no way to destroy a secondary window through
  /// this seam: `desktop_multi_window`'s controller exposes show, hide and
  /// messages only, so a window that was created and then failed to configure
  /// stays in the process until it exits. Worth knowing before anything is built
  /// that opens windows speculatively.
  Future<void> hide();

  /// Sends [method] with [arguments] into that window's isolate.
  ///
  /// The only way anything crosses between engines here, which is why the
  /// arguments must be encodable — pass an identifier and let the other side
  /// load what it needs, rather than trying to hand it a live object.
  ///
  /// **This is not the same transport as [show], and the difference is a race.**
  /// Show and hide are carried out by the operating system on a window the plugin
  /// already owns; a message goes to the *engine* on the other side and is only
  /// delivered once that isolate has registered its handler, which happens some
  /// time after creation. So `open()` followed immediately by `send()` can arrive
  /// before anybody is listening, and the receiving end — not the sender — decides
  /// whether that is an error. The reliable shape is the other way round: let the
  /// new window ask for what it needs through [WindowLauncher] arguments at
  /// start-up, and reserve [send] for telling an already-visible window to change
  /// something it is showing.
  Future<T?> send<T>(String method, [Object? arguments]);
}
