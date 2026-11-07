import 'package:flutter/foundation.dart' show ChangeNotifier;

/// "A dialog owns the remote now." While locked, card and row select
/// handlers stand down, so a select meant for a control behind the dialog
/// cannot fire through it — dialog focus trees outlive their exit
/// animation, and a held key's repeats would otherwise land on the card
/// that happens to have focus underneath.
final class TvDialogLock extends ChangeNotifier {
  bool _locked = false;

  /// Whether a TV dialog is currently up.
  bool get locked => _locked;

  /// Takes the lock when a dialog opens.
  void lock() {
    if (_locked) return;
    _locked = true;
    notifyListeners();
  }

  /// Releases the lock; the show wrapper delays this past the dialog's
  /// exit animation.
  void unlock() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }
}

/// One per process, like the playback receiver.
final TvDialogLock tvDialogLock = TvDialogLock();

/// The synchronous check every select handler makes before acting.
bool get tvDialogLockedNow => tvDialogLock.locked;
