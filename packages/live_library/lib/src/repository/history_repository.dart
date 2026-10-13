import 'dart:async';

import 'package:live_library/src/model/library_room.dart';
import 'package:live_library/src/store/library_store.dart';
import 'package:live_sites/live_sites.dart';

/// The watch history: newest first, with a fixed cap.
///
/// Recording the same room again moves it to the top instead of
/// duplicating; the snapshot is refreshed with every visit, which is the
/// point of a history (the user metadata lives in the follow records).
final class HistoryRepository {
  /// A repository over [store]; [capacity] caps the list length.
  new(this.store, {this.capacity = 300});

  /// The persistence seam.
  final LibraryStore store;

  /// The largest list kept; older entries fall off.
  final int capacity;

  final _changes = StreamController<void>.broadcast();
  List<WatchRecord> _history = const [];
  bool _loaded = false;
  StreamSubscription<void>? _external;
  int _seq = 0;

  /// Emits after every committed mutation.
  Stream<void> get changes => _changes.stream;

  /// The history, newest first.
  List<WatchRecord> get records => List.unmodifiable(_history);

  /// Loads from the store (idempotent).
  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    _history = await store.loadHistory();
    _seq = _history.isEmpty ? 0 : _history.map((record) => record.seq).reduce((a, b) => a > b ? a : b) + 1;
    _external ??= store.changes.listen((_) => unawaited(_reload()));
  }

  /// Records a visit to [room]; an existing entry moves to the top.
  Future<void> record(LiveRoom room) async {
    final entry = WatchRecord(room: room, watchedAt: DateTime.now(), seq: _seq++);
    _history = [
      entry,
      for (final record in _history)
        if (record.identity != room.identityKey) record,
    ];
    if (_history.length > capacity) {
      _history = _history.sublist(0, capacity);
    }
    await _commit();
  }

  /// Removes one room's entry.
  Future<void> remove(LiveRoom room) async {
    final next = [
      for (final record in _history)
        if (record.identity != room.identityKey) record,
    ];
    if (next.length == _history.length) {
      return;
    }
    _history = next;
    await _commit();
  }

  /// Clears the whole history.
  Future<void> clear() async {
    if (_history.isEmpty) {
      return;
    }
    _history = const [];
    await _commit();
  }

  /// Releases the repository.
  Future<void> dispose() async {
    await _external?.cancel();
    _external = null;
    await _changes.close();
  }

  Future<void> _commit() async {
    await store.saveHistory(_history);
    _changes.add(null);
  }

  Future<void> _reload() async {
    _history = await store.loadHistory();
    _changes.add(null);
  }
}
