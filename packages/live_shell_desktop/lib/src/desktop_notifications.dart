import 'package:nativeapi/nativeapi.dart' as native;

/// System notifications over `nativeapi`'s notification manager — the same
/// native stack `tray_manager` 0.8 moved onto, so the app's toasts and its
/// tray icon speak one dialect.
///
/// Strictly best-effort, like the tray itself: a platform with no notification
/// surface (or a Windows identity the store has not registered) answers false
/// at `isSupported`/`initialize`/`show`, and every one of those answers is a
/// silent drop, never a failed call. The recorder's notices are the only
/// sender today, and a recording that finished is a fact whether or not a
/// toast appeared.
final class DesktopNotificationCenter {
  /// A center that initializes lazily on the first show and remembers a
  /// refused initialization instead of asking the OS again every notice.
  new();

  bool? _usable;

  /// Whether this platform has a notification surface at all.
  bool get supported => native.NotificationManager.instance.isSupported();

  /// Posts one notice under [tag] (one tag replaces its own predecessor, so
  /// a burst of completions does not pile up a wall of toasts). Returns
  /// whether the system took it; false means dropped, not queued.
  bool show({required String title, String body = '', String tag = 'pure_live'}) {
    final usable = _usable ??= _init();
    if (!usable) return false;
    return native.NotificationManager.instance.show(title, body, tag, '');
  }

  bool _init() {
    if (!supported) return false;
    return native.NotificationManager.instance.initialize();
  }
}
