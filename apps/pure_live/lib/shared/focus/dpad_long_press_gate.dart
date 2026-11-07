/// Swallows the select that leaks out of a long-press.
///
/// A control with a long-press action defers select until key-up; when that
/// press is disturbed (a remote emitting a stray down/up pair, the card
/// rebuilt mid-hold, a dialog borrowing the focus and giving it back), the
/// key-up still reports select and the viewer opens the room they meant to
/// long-press a menu on. The control marks the long-press here; the select
/// that arrives within the window after it is dropped.
final class DpadLongPressGate {
  /// How long after a marked long-press a select is still treated as its
  /// leaking tail.
  static const Duration _window = Duration(seconds: 1);

  DateTime? _firedAt;

  /// Records that this control just served a long-press.
  void markLongPress() => _firedAt = DateTime.now();

  /// Consumes the mark: true when a select right now is that leaking tail.
  bool swallowSelect() {
    final at = _firedAt;
    _firedAt = null;
    return at != null && DateTime.now().difference(at) < _window;
  }
}
