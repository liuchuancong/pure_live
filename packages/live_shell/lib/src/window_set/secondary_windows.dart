import 'package:live_shell/src/window_host/window_host.dart';
import 'package:live_shell/src/window_role/window_role.dart';

/// The windows other than the primary one, and what may exist twice.
///
/// Why this is a type and not a `List` in the app: a secondary window costs
/// memory and attention, and the two mistakes that follow from forgetting that
/// are both common. The first is a **second floating video window** appearing
/// because the viewer pressed the button twice and the code had nowhere to ask
/// "is there already one" — the float is a view of one session, so two of them
/// are always a bug. The second is a **panel that multiplies**: the log view and
/// the cast panel are genuinely allowed to be open several times, over different
/// content, and an app that treats them like the float makes the viewer close one
/// to see the other.
///
/// So the rule is per role, stated once here, and every entry point goes through
/// it: [open] raises what already exists where the role is a singleton, and
/// creates freely where it is not.
class SecondaryWindows {
  /// A set of windows created through [launcher].
  new({required this.launcher});

  /// Where new windows come from.
  final WindowLauncher launcher;

  final Map<String, SecondaryWindow> _byId = {};

  /// The roles where a second window is never wanted.
  ///
  /// A floating video window mirrors the primary's session, so a second one
  /// shows the same picture in a second frame. A popup is a toast: two toasts
  /// saying the same thing is a stacking bug the viewer has to clear by hand.
  static bool isSingleton(WindowRole role) => role == WindowRole.videoFloat || role == WindowRole.popup;

  /// Every window currently tracked.
  List<SecondaryWindow> get opened => List<SecondaryWindow>.unmodifiable(_byId.values);

  /// The window of [role], when the role has at most one and it is open.
  SecondaryWindow? lone(WindowRole role) {
    for (final window in _byId.values) {
      if (window.role == role) {
        return window;
      }
    }
    return null;
  }

  /// How many of [role] are open.
  int countOf(WindowRole role) => _byId.values.where((window) => window.role == role).length;

  /// Opens a window of [role], or raises the one that is already there.
  ///
  /// Returning the existing window rather than failing is what makes a double
  /// press feel correct: the viewer asked for the float, they get the float, and
  /// it comes forward rather than a second one appearing behind it.
  Future<SecondaryWindow> open({required WindowRole role, String? route, String? businessKey}) async {
    final existing = isSingleton(role) ? lone(role) : null;
    if (existing != null) {
      await existing.show();
      return existing;
    }
    final window = await launcher.open(role: role, route: route, businessKey: businessKey);
    _byId[window.id] = window;
    return window;
  }

  /// Forgets a window that went away on its own — its close button, or a crash
  /// of its engine.
  ///
  /// Without this a singleton role is permanently occupied by a window that no
  /// longer exists, and the float button stops working for the rest of the
  /// session with nothing on screen to explain why.
  void noteGone(String id) => _byId.remove(id);

  /// Asks every window of [role] to close, and forgets them.
  Future<void> dismissRole(WindowRole role) async {
    for (final window in _byId.values.where((entry) => entry.role == role).toList()) {
      await _dismiss(window);
      _byId.remove(window.id);
    }
  }

  /// Asks every secondary window to close. The quit path's last step, so a
  /// forgotten panel cannot keep the process alive after the main window is gone.
  Future<void> dismissAll() async {
    for (final window in _byId.values.toList()) {
      await _dismiss(window);
    }
    _byId.clear();
  }

  /// Sends the dismiss and forgets the window either way. A window that
  /// answers nothing — its engine dying mid-quit, its handler not armed yet —
  /// is already as good as gone, and a failure here would run through the quit
  /// path: the viewer pressed quit and the app stayed, the worst possible
  /// moment for a channel to have opinions.
  Future<void> _dismiss(SecondaryWindow window) async {
    try {
      await window.send<void>('shell_dismiss');
    } on Object {
      // Already gone, or gone by the time the send landed.
    }
    _byId.remove(window.id);
  }

  /// Raises every window the viewer can see, used when the app is reactivated
  /// after being found with its panels still open.
  Future<void> raiseAll() async {
    for (final window in _byId.values) {
      await window.show();
    }
  }
}
