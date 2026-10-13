import 'package:live_sites/live_sites.dart';

/// The latest audience readings of one room.
///
/// Consumes the `LiveMessageType.audienceUpdate` messages that decoders
/// emit (the `LiveAudienceUpdate` payload: one `{kind, value}` reading per
/// message) and keeps the latest value per metric; listeners are notified
/// when a reading changes. Popularity is heat, not a head count, and is
/// never filed here.
final class AudienceTracker {
  /// An empty tracker.
  new();

  int? _totalViewers;
  int? _onlineViewers;
  final List<void Function()> _listeners = [];

  /// The latest cumulative viewer count, if one arrived.
  int? get totalViewers => _totalViewers;

  /// The latest concurrent viewer count, if one arrived.
  int? get onlineViewers => _onlineViewers;

  /// Adds a change listener.
  void addListener(void Function() listener) => _listeners.add(listener);

  /// Removes a change listener.
  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Feeds one message; audience updates carry the readings.
  void consume(LiveMessage message) {
    if (message.type != LiveMessageType.audienceUpdate) {
      return;
    }
    final payload = message.payload;
    if (payload is! LiveAudienceUpdate) {
      return;
    }
    var changed = false;
    switch (payload.kind) {
      case LiveAudienceSignalKind.totalViewers:
        if (payload.value != _totalViewers) {
          _totalViewers = payload.value;
          changed = true;
        }
      case LiveAudienceSignalKind.onlineViewers:
        if (payload.value != _onlineViewers) {
          _onlineViewers = payload.value;
          changed = true;
        }
      case LiveAudienceSignalKind.popularity:
        break;
    }
    if (!changed) {
      return;
    }
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  /// Resets the readings (a new room in the same session).
  void reset() {
    _totalViewers = null;
    _onlineViewers = null;
  }
}
