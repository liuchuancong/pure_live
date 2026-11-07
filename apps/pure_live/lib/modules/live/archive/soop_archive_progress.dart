import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The replay walk's own progress namespace: a recording's parts, keyed by
/// their part ids, with the position each one stopped at. The store keeps a
/// bounded map — the oldest entries fall off the front when a viewer's walk
/// outgrows the room — and a closed store only loses the persistence, like
/// every preference here.
final class SoopArchiveProgress {
  static const String _key = 'archive.soop.progress';

  /// The most positions one namespace holds before the oldest give way.
  static const int _limit = 200;

  /// The position [partId] stopped at; a negative duration when the part
  /// has none, so `zero` keeps its meaning of "watched from the start".
  Duration position(String partId) {
    final millis = _read()[partId];
    if (millis == null) return const Duration(milliseconds: -1);
    return Duration(milliseconds: millis);
  }

  /// The part of the recording named by [prefix] (`<recording>:`) that the
  /// viewer stopped in last; null when the recording has no saved walk.
  String? recent(String prefix) {
    String? found;
    for (final entry in _read().entries) {
      if (entry.key.startsWith(prefix)) found = entry.key;
    }
    return found;
  }

  /// Records where [partId] stopped; a completed part saves its start, so
  /// the next open begins again.
  Future<void> save(String partId, Duration position) async {
    final store = _read()
      ..remove(partId)
      ..[partId] = position.inMilliseconds;
    while (store.length > _limit) {
      store.remove(store.keys.first);
    }
    try {
      await StoragePrefs.setString(_key, jsonEncode(store));
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  Map<String, int> _read() {
    try {
      final raw = StoragePrefs.getString(_key);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final store = <String, int>{};
      decoded.forEach((key, value) {
        if (key is String && key.isNotEmpty && value is num) store[key] = value.toInt();
      });
      return store;
    } on Object {
      return {};
    }
  }
}
