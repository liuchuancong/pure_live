import 'package:live_storage/src/repository/hive_storage_repository.dart';
import 'package:live_storage/src/repository/storage_list_repository.dart';

/// Implements list-specific storage operations using Hive CE.
final class HiveStorageListRepository<E> extends HiveStorageRepository<List<E>> implements StorageListRepository<E> {
  /// Creates a list repository backed by an already-open Hive CE box.
  new({required super.box});

  @override
  Future<bool> append(String key, E value) {
    return _modify(key, (list) => list.add(value));
  }

  @override
  Future<bool> appendAll(String key, Iterable<E> values) {
    final additions = List<E>.of(values);
    return _modify(key, (list) => list.addAll(additions));
  }

  @override
  Future<bool> insert(String key, int index, E value) {
    return _modify(key, (list) => list.insert(index, value));
  }

  @override
  Future<bool> remove(String key, E value) async {
    var removed = false;

    final exists = await _modify(key, (list) {
      removed = list.remove(value);
    });

    return exists && removed;
  }

  @override
  Future<E?> removeAt(String key, int index) async {
    E? removed;

    final exists = await _modify(key, (list) {
      RangeError.checkValidIndex(index, list, 'index');
      removed = list.removeAt(index);
    });

    return exists ? removed : null;
  }

  @override
  Future<bool> replaceAt(String key, int index, E value) {
    return _modify(key, (list) {
      RangeError.checkValidIndex(index, list, 'index');
      list[index] = value;
    });
  }

  @override
  E? elementAt(String key, int index) {
    final list = get(key);
    if (list == null) return null;

    RangeError.checkValidIndex(index, list, 'index');
    return list[index];
  }

  @override
  int? length(String key) => get(key)?.length;

  @override
  bool containsValue(String key, E value) {
    return get(key)?.contains(value) ?? false;
  }

  @override
  Future<int?> removeWhere(String key, bool Function(E element) test) async {
    int? removedCount;

    final exists = await _modify(key, (list) {
      final originalLength = list.length;
      list.removeWhere(test);
      removedCount = originalLength - list.length;
    });

    return exists ? removedCount : null;
  }

  @override
  Future<bool> sort(String key, [int Function(E a, E b)? compare]) {
    return _modify(key, (list) => list.sort(compare));
  }

  @override
  Future<bool> reverse(String key) {
    return _modify(key, (list) {
      final reversed = list.reversed.toList();
      list
        ..clear()
        ..addAll(reversed);
    });
  }

  Future<bool> _modify(String key, void Function(List<E> list) operation) {
    return update(key, (current) {
      final updated = List<E>.of(current);
      operation(updated);
      return updated;
    });
  }
}
