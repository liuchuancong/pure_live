import 'dart:ui';

/// Persistence for the geometry a viewer gave a small window.
///
/// The host supplies an implementation — `HiveWindowPreferenceStore` over
/// `live_storage` in the app, `EphemeralWindowPreferenceStore` where there is
/// no disk — so the module itself stays storage-agnostic.
///
/// A hidden window's rect is remembered *after the drag settles*, not on
/// every frame: the position worth remembering is the one the viewer chose,
/// not the one the finger passed through.
abstract interface class WindowPreferenceStore {
  /// The remembered rect for [sessionId]'s [slot], when one exists.
  ///
  /// [slot] is produced by `WindowGeometryKey.slot` and already includes the
  /// video orientation, so a portrait layout never overwrites a landscape one.
  Future<Rect?> readRect({required String sessionId, required String slot});

  /// Remembers [rect] for [sessionId]'s [slot].
  Future<void> writeRect({required String sessionId, required String slot, required Rect rect});

  /// Forgets every remembered geometry for a session.
  ///
  /// Called when the viewer clears their layout, not when a room closes: a
  /// room visited twice a week should still come back the way it was left.
  Future<void> clearSession(String sessionId);

  /// Forgets everything.
  Future<void> clearAll();
}

/// A store that remembers nothing.
///
/// The default for hosts that have not wired persistence yet, and for tests
/// that do not care about it. Windows still work; they just open at their
/// default position every time.
final class EphemeralWindowPreferenceStore implements WindowPreferenceStore {
  /// Creates an ephemeral store.
  new();

  final Map<String, Rect> _rects = <String, Rect>{};

  @override
  Future<Rect?> readRect({required String sessionId, required String slot}) async => _rects['$sessionId/$slot'];

  @override
  Future<void> writeRect({required String sessionId, required String slot, required Rect rect}) async {
    _rects['$sessionId/$slot'] = rect;
  }

  @override
  Future<void> clearSession(String sessionId) async {
    _rects.removeWhere((key, _) => key.startsWith('$sessionId/'));
  }

  @override
  Future<void> clearAll() async {
    _rects.clear();
  }
}
