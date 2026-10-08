import 'dart:collection';

/// Tracks arrivals between bounded message-history snapshots.
class DanmakuArrivalCounter<T extends Object> {
  Set<T> _previous = HashSet<T>.identity();

  int update(List<T> messages) {
    // The controller trims the head at capacity and can remove blocked rows.
    // Neither list length nor a changed tail identifies how many arrived.
    // Retain only the current bounded snapshot, not a session-long seen set.
    final next = HashSet<T>.identity()..addAll(messages);
    final added = next.where((message) => !_previous.contains(message)).length;
    _previous = next;
    return added;
  }
}
