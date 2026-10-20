import 'dart:async';

import 'package:live_library/src/model/library_room.dart';
import 'package:live_library/src/store/library_store.dart';
import 'package:live_sites/live_sites.dart' show LiveArea;

/// The followed partitions: the areas the user asked to keep an eye on.
///
/// A follow is keyed by `platform:areaId` and holds the name the platform
/// gave it, so the list reads without a network round-trip and a re-follow
/// only ever moves the entry rather than duplicating it.
final class FollowAreaRepository {
  /// A repository over [store].
  new(this.store);

  /// The persistence seam.
  final LibraryStore store;

  final _changes = StreamController<void>.broadcast();
  final List<FollowArea> _areas = [];
  bool _loaded = false;
  StreamSubscription<void>? _external;

  /// Emits after every committed mutation, including another window's.
  Stream<void> get changes => _changes.stream;

  /// The followed partitions, in the user's order.
  List<FollowArea> get areas => List.unmodifiable(_areas);

  /// Loads from the store (idempotent).
  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    _areas
      ..clear()
      ..addAll(await store.loadAreas());
    _external ??= store.changes.listen((_) => unawaited(_reload()));
  }

  /// Whether [area] is followed.
  bool isFollowing(LiveArea area) => _areas.any((followed) => followed.identityKey == _key(area));

  /// Follows [area]. Following it again refreshes the name and moves it to the
  /// top, which is what a re-tap of the pill means at the end of a long list.
  Future<void> follow(LiveArea area) async {
    final key = _key(area);
    final existing = _areas.where((followed) => followed.identityKey == key).firstOrNull;
    _areas.removeWhere((followed) => followed.identityKey == key);
    _areas.insert(
      0,
      existing?.copyWith(name: area.areaName, followedAt: DateTime.now()) ??
          FollowArea(platform: area.platform, areaId: area.areaId, name: area.areaName, followedAt: DateTime.now()),
    );
    await _commit();
  }

  /// Stops following [area]; a partition that was not followed changes nothing.
  Future<void> unfollow(LiveArea area) async {
    final key = _key(area);
    final before = _areas.length;
    _areas.removeWhere((followed) => followed.identityKey == key);
    if (_areas.length == before) {
      return;
    }
    await _commit();
  }

  /// Moves the followed partition [identityKey] to [targetIndex].
  Future<void> move(String identityKey, int targetIndex) async {
    final index = _areas.indexWhere((followed) => followed.identityKey == identityKey);
    if (index < 0) {
      return;
    }
    final area = _areas.removeAt(index);
    _areas.insert(targetIndex.clamp(0, _areas.length), area);
    await _commit();
  }

  /// Stops watching the store and closes [changes].
  Future<void> dispose() async {
    await _external?.cancel();
    await _changes.close();
  }

  /// Rewrites the stored document with the list renumbered, then echoes the
  /// numbered records back into memory, so the order the page shows is the
  /// order that was saved.
  Future<void> _commit() async {
    final positioned = [for (final (index, area) in _areas.indexed) area.copyWith(position: index)];
    await store.saveAreas(positioned);
    _areas
      ..clear()
      ..addAll(positioned);
    _changes.add(null);
  }

  Future<void> _reload() async {
    final stored = await store.loadAreas();
    _areas
      ..clear()
      ..addAll(stored);
    _changes.add(null);
  }

  static String _key(LiveArea area) => '${area.platform}:${area.areaId}';
}
