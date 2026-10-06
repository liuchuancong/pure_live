import 'dart:async';

import 'package:media_core/media_core.dart' show PlayerId, PlayerKernel;

/// Keeps a player handle alive after the page that opened it is gone.
///
/// The small window is driven by the kernel's [FloatingDriver], but the player
/// itself belongs to whoever created it: the local video player's feed owns the
/// handle, and GetX deletes that controller — and the feed with it — the moment
/// its route is popped. Handing the feed over here is what lets the window keep
/// playing after the page closes; the keeper is released when the window is
/// expanded or closed, so the handle never outlives the last surface showing it.
///
/// Deliberately core-level and free of any domain knowledge: the presenter that
/// closes the window and the page that opens the file only agree on a player id.
final class FloatingHandleKeeper {
  FloatingHandleKeeper._();

  static final FloatingHandleKeeper instance = FloatingHandleKeeper._();

  final Map<String, Future<void> Function()> _owners = <String, Future<void> Function()>{};
  final Map<String, Future<void> Function()> _expanders = <String, Future<void> Function()>{};

  /// The handle the small window is currently showing, if any.
  String? get currentId => _currentId;
  String? _currentId;

  /// Whether [playerId] was handed over and is still alive.
  bool owns(String playerId) => _owners.containsKey(playerId);

  /// Hands [playerId] to the small window.
  ///
  /// [release] runs when the window closes (it is what disposes the player a
  /// page would otherwise have disposed), [onExpand] when the viewer asks for
  /// the full page back. Handing over a second handle releases the first, so a
  /// viewer who floats recording after recording never leaves one playing
  /// invisibly behind the other.
  Future<void> own(String playerId, Future<void> Function() release, {Future<void> Function()? onExpand}) async {
    await releaseCurrent();
    _owners[playerId] = release;
    if (onExpand != null) _expanders[playerId] = onExpand;
    _currentId = playerId;
  }

  /// Runs the expand action for [playerId], if the host registered one.
  Future<void> expand(String playerId) async {
    final expand = _expanders[playerId];
    if (expand != null) await expand();
  }

  /// Releases one handle; the release callback runs once.
  Future<void> release(String playerId) async {
    if (identical(_currentId, playerId)) _currentId = null;
    _expanders.remove(playerId);
    final release = _owners.remove(playerId);
    if (release == null) return;
    await release();
  }

  /// Releases whichever handle the window is showing, if any.
  Future<void> releaseCurrent() async {
    final id = _currentId;
    if (id == null) return;
    await release(id);
  }

  /// Takes the small window down: the driver leaves the mode (which hides the
  /// host's overlay) and the handle is released.
  ///
  /// [releaseCurrent] alone only disposes the player. The window itself is the
  /// driver's, so a viewer who floats a recording and then opens the recorder's
  /// player was left with an invisible window still on screen — the picture went
  /// black because its player was gone, but the overlay stayed and kept eating
  /// its corner of the surface. Anything that takes the surface back calls this.
  ///
  /// Returns whether a window was actually up.
  static Future<bool> reclaimCurrent(PlayerKernel kernel) async {
    final keeper = instance;
    final id = keeper._currentId;
    if (id == null) return false;
    await kernel.exitFloating(PlayerId(id));
    await keeper.release(id);
    return true;
  }
}
