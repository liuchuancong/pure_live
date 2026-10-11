import 'package:live_sites/live_sites.dart';

/// The latest audience readings of one room.
///
/// Consumes the `LiveMessageType.audienceUpdate` messages that decoders
/// emit (the `LiveAudienceUpdate` payload) and keeps the latest value per
/// metric; listeners are notified when a reading changes.
final class AudienceTracker {
  /// An empty tracker.
  new();

  int? _watching;
  int? _onlineViewers;
  final List<void Function()> _listeners = [];

  /// The latest watcher count, if one arrived.
  int? get watching => _watching;

  /// The latest cumulative viewer count, if one arrived.
  int? get onlineViewers => _onlineViewers;

  /// Adds a change listener.
  void addListener(void Function() listener) => _listeners.add(listener);

  /// Removes a change listener.
  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Feeds one message; audience updates and room refreshes carry the
  /// readings.
  void consume(LiveMessage message) {
    if (message.type != LiveMessageType.audienceUpdate) {
      return;
    }
    final data = message.data;
    if (data is! LiveAudienceUpdate) {
      return;
    }
    var changed = false;
    final watching = data.watching;
    if (watching != null && watching != _watching) {
      _watching = watching;
      changed = true;
    }
    final online = data.onlineViewers;
    if (online != null && online != _onlineViewers) {
      _onlineViewers = online;
      changed = true;
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
    _watching = null;
    _onlineViewers = null;
  }
}
