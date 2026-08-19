import 'dart:collection';

import 'package:pure_live/common/models/live_message.dart';

/// Collapses a short burst of identical audience text into its first message.
///
/// This is intentionally separate from [DanmakuMessageGate]: the gate rejects
/// replayed packets from one sender/ID, while this optional user-facing filter
/// suppresses copy-paste text sent by different accounts. Local and system
/// messages are never affected.
class RepeatedDanmakuFilter {
  RepeatedDanmakuFilter({this.maxEntries = 1024});

  final int maxEntries;
  final LinkedHashMap<String, DateTime> _lastSeen = LinkedHashMap<String, DateTime>();

  bool accepts(LiveMessage message, {required bool enabled, required Duration window, DateTime? now}) {
    if (!enabled) {
      if (_lastSeen.isNotEmpty) _lastSeen.clear();
      return true;
    }
    if (message.type != LiveMessageType.chat || message.isLocal) return true;

    final normalized = message.message.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    if (normalized.isEmpty) return true;

    final receivedAt = now ?? DateTime.now();
    final previous = _lastSeen.remove(normalized);
    _lastSeen[normalized] = receivedAt;
    _evict(receivedAt, window);
    return previous == null || receivedAt.difference(previous) > window;
  }

  void clear() => _lastSeen.clear();

  void _evict(DateTime now, Duration window) {
    final oldestAllowed = now.subtract(window);
    while (_lastSeen.isNotEmpty && _lastSeen.values.first.isBefore(oldestAllowed)) {
      _lastSeen.remove(_lastSeen.keys.first);
    }
    while (_lastSeen.length > maxEntries) {
      _lastSeen.remove(_lastSeen.keys.first);
    }
  }
}
