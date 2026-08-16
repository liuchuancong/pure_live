import 'dart:collection';

import 'package:pure_live/common/models/live_message.dart';

/// Rejects platform backlog and duplicate delivery while keeping memory
/// bounded. Stable platform IDs receive a longer replay window; platforms
/// without IDs use a deliberately short text fingerprint window so repeated
/// audience messages remain visible.
class DanmakuMessageGate {
  DanmakuMessageGate({
    this.fallbackDuplicateWindow = const Duration(milliseconds: 2500),
    this.stableIdWindow = const Duration(minutes: 10),
    this.maxMessageAge = const Duration(seconds: 45),
    this.maxEntries = 4096,
  });

  final Duration fallbackDuplicateWindow;
  final Duration stableIdWindow;
  final Duration maxMessageAge;
  final int maxEntries;

  final LinkedHashMap<String, DateTime> _seen = LinkedHashMap<String, DateTime>();

  bool accepts(LiveMessage message, {DateTime? now}) {
    final receivedAt = now ?? DateTime.now();
    final sentAt = message.sentAt;
    if (sentAt != null) {
      final age = receivedAt.difference(sentAt);
      if (age > maxMessageAge) return false;
      // A small amount of device/server clock skew is normal. Very large
      // future timestamps are malformed and should not poison the ID cache.
      if (age < const Duration(minutes: -10)) return false;
    }

    final stableId = message.messageId.trim();
    final hasStableId = stableId.isNotEmpty;
    final key = hasStableId
        ? 'id:$stableId'
        : 'text:${message.type.index}:${message.userId.trim().toLowerCase()}:'
              '${message.userName.trim().toLowerCase()}:${message.message.trim()}';
    final duplicateWindow = hasStableId ? stableIdWindow : fallbackDuplicateWindow;

    final previous = _seen.remove(key);
    if (previous != null && receivedAt.difference(previous) <= duplicateWindow) {
      _seen[key] = previous;
      return false;
    }

    _seen[key] = receivedAt;
    _evictExpired(receivedAt);
    return true;
  }

  void clear() => _seen.clear();

  void _evictExpired(DateTime now) {
    final oldestAllowed = now.subtract(stableIdWindow);
    while (_seen.isNotEmpty && _seen.values.first.isBefore(oldestAllowed)) {
      _seen.remove(_seen.keys.first);
    }
    while (_seen.length > maxEntries) {
      _seen.remove(_seen.keys.first);
    }
  }
}
