import 'dart:ui';

import 'package:live_playback/src/config/window_preference_store.dart';
import 'package:live_storage/live_storage.dart';

/// A [WindowPreferenceStore] on the app's Hive storage.
///
/// One box, one entry per session: the value stored under a session id is a
/// map from slot (`<surface>_<orientation>`) to the four numbers of the rect
/// the viewer left that window at. A map per session rather than one flat key
/// space because forgetting a session then means deleting one key — no prefix
/// scanning, and no chance of a session id that is a prefix of another taking
/// its neighbour's layouts with it.
///
/// The repository serializes read-modify-write per key, so two small windows
/// of the same room (PiP and floating) can never lose each other's write, and
/// a room laid out on a different screen keeps its entry until the viewer
/// clears it.
final class HiveWindowPreferenceStore implements WindowPreferenceStore {
  /// Creates the store.
  ///
  /// [boxes] is the app's box manager; the host must have completed
  /// `StorageBootstrap.initialize()` before the first read or write. Nothing
  /// is opened here, so constructing the store during startup is free and a
  /// host that only ever uses the ephemeral store never touches the disk.
  new({StorageBoxManager? boxes, this.boxName = defaultBoxName}) : _boxes = boxes ?? StorageBoxManager();

  /// The box the remembered layouts live in.
  static const String defaultBoxName = 'live_playback_window_geometry';

  /// The box this store reads and writes.
  final String boxName;

  final StorageBoxManager _boxes;

  Future<HiveStorageMapRepository<String, List<double>>>? _repository;

  @override
  Future<Rect?> readRect({required String sessionId, required String slot}) async {
    final values = (await _repo()).getEntry(sessionId, slot);
    if (values == null || values.length != 4) {
      // A partial entry (a write interrupted by a kill) reads as "no
      // preference" rather than as a zero-sized window at the origin.
      return null;
    }

    return Rect.fromLTWH(values[0], values[1], values[2], values[3]);
  }

  @override
  Future<void> writeRect({required String sessionId, required String slot, required Rect rect}) async {
    final values = <double>[rect.left, rect.top, rect.width, rect.height];
    final repository = await _repo();

    // The map-entry operations only rewrite an entry that already exists — each
    // one is a read-modify-write over the session's map — so a room's first
    // window seeds the entry. Both calls serialize per session inside the
    // repository, so two windows of one room opening at the same moment still
    // both land.
    final seeded = await repository.insertIfAbsent(sessionId, <String, List<double>>{slot: values});
    if (!seeded) {
      await repository.setEntry(sessionId, slot, values);
    }
  }

  @override
  Future<void> clearSession(String sessionId) async {
    await (await _repo()).delete(sessionId);
  }

  @override
  Future<void> clearAll() async {
    await (await _repo()).clear();
  }

  Future<HiveStorageMapRepository<String, List<double>>> _repo() => _repository ??= _open();

  Future<HiveStorageMapRepository<String, List<double>>> _open() async {
    // `keyed` rather than `map`: the storage repositories wrap a keyed box
    // whose values happen to be maps, and `MapBox` is a different handle family
    // that the repository layer cannot take.
    final box = await _boxes.keyed<Map<String, List<double>>>(boxName);
    return HiveStorageMapRepository<String, List<double>>(box: box);
  }
}
