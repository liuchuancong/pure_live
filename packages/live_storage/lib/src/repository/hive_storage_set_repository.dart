import 'package:live_storage/src/repository/hive_storage_repository.dart';
import 'package:live_storage/src/repository/storage_set_repository.dart';

/// Implements set-specific storage operations using Hive CE.
final class HiveStorageSetRepository<E> extends HiveStorageRepository<Set<E>> implements StorageSetRepository<E> {
  /// Creates a set repository backed by an already-open Hive CE box.
  new({required super.box});

  @override
  Future<bool> addValue(String key, E value) async {
    var added = false;

    final exists = await update(key, (current) {
      final updated = Set<E>.of(current);
      added = updated.add(value);
      return updated;
    });

    return exists && added;
  }

  @override
  Future<int?> addAllValues(String key, Iterable<E> values) async {
    final additions = Set<E>.of(values);
    var addedCount = 0;

    final exists = await update(key, (current) {
      final updated = Set<E>.of(current);
      final originalLength = updated.length;

      updated.addAll(additions);
      addedCount = updated.length - originalLength;

      return updated;
    });

    return exists ? addedCount : null;
  }

  @override
  Future<bool> removeValue(String key, E value) async {
    var removed = false;

    final exists = await update(key, (current) {
      final updated = Set<E>.of(current);
      removed = updated.remove(value);
      return updated;
    });

    return exists && removed;
  }

  @override
  Future<int?> removeAllValues(String key, Iterable<E> values) async {
    final removals = Set<E>.of(values);
    var removedCount = 0;

    final exists = await update(key, (current) {
      final updated = Set<E>.of(current);
      final originalLength = updated.length;

      updated.removeAll(removals);
      removedCount = originalLength - updated.length;

      return updated;
    });

    return exists ? removedCount : null;
  }

  @override
  bool containsValue(String key, E value) {
    return get(key)?.contains(value) ?? false;
  }

  @override
  int? length(String key) => get(key)?.length;

  @override
  Set<E>? values(String key) {
    final set = get(key);
    if (set == null) return null;

    return Set<E>.unmodifiable(set);
  }

  @override
  Future<bool> unionWith(String key, Set<E> other) {
    final additions = Set<E>.of(other);

    return update(key, (current) {
      return Set<E>.of(current)..addAll(additions);
    });
  }

  @override
  Future<bool> intersectWith(String key, Set<E> other) {
    final retained = Set<E>.of(other);

    return update(key, (current) {
      return Set<E>.of(current)..retainAll(retained);
    });
  }

  @override
  Future<bool> differenceWith(String key, Set<E> other) {
    final removals = Set<E>.of(other);

    return update(key, (current) {
      return Set<E>.of(current)..removeAll(removals);
    });
  }

  @override
  Future<int?> removeWhere(String key, bool Function(E value) test) async {
    var removedCount = 0;

    final exists = await update(key, (current) {
      final updated = Set<E>.of(current);
      final originalLength = updated.length;

      updated.removeWhere(test);
      removedCount = originalLength - updated.length;

      return updated;
    });

    return exists ? removedCount : null;
  }
}
