/// Shows a status notice once per [window] (3.x
/// `DanmakuController._addStatusMessage`): the same notice again within the
/// window is dropped, and a dropped notice does not extend it.
// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor
final class DanmakuNoticeThrottle {
  /// Creates the throttle with 3.x's 3 s window.
  DanmakuNoticeThrottle({this.window = const Duration(seconds: 3), DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Quiet period for one notice.
  final Duration window;

  final DateTime Function() _clock;
  Object? _last;
  DateTime? _lastAt;

  /// Whether [notice] (its text or any value with `==`) should be shown now.
  bool accepts(Object notice) {
    final now = _clock();
    final lastAt = _lastAt;
    if (_last == notice && lastAt != null && now.difference(lastAt) < window) return false;
    _last = notice;
    _lastAt = now;
    return true;
  }
}
