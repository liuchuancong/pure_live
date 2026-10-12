import 'package:live_storage/src/repository/hive_storage_repository.dart';
import 'package:live_storage/src/repository/storage_map_repository.dart';

/// Implements map-specific storage operations using Hive CE.
final class HiveStorageMapRepository<K, V> extends HiveStorageRepository<Map<K, V>>
    implements StorageMapRepository<K, V> {
  /// Creates a map repository backed by an already-open Hive CE box.
  new({required super.box});

  @override
  Future<bool> setEntry(String key, K entryKey, V value) {
    return _modify(key, (map) {
      map[entryKey] = value;
    });
  }

  @override
  Future<bool> setEntries(String key, Map<K, V> entries) {
    final additions = Map<K, V>.of(entries);

    return _modify(key, (map) {
      map.addAll(additions);
    });
  }

  @override
  V? getEntry(String key, K entryKey) {
    return get(key)?[entryKey];
  }

  @override
  bool containsEntry(String key, K entryKey) {
    return get(key)?.containsKey(entryKey) ?? false;
  }

  @override
  Future<bool> removeEntry(String key, K entryKey) {
    return _modify(key, (map) {
      map.remove(entryKey);
    });
  }

  @override
  Future<int?> removeEntries(String key, Iterable<K> entryKeys) async {
    final keysToRemove = Set<K>.of(entryKeys);
    var removedCount = 0;

    final exists = await _modify(key, (map) {
      for (final entryKey in keysToRemove) {
        if (map.containsKey(entryKey)) {
          map.remove(entryKey);
          removedCount++;
        }
      }
    });

    return exists ? removedCount : null;
  }

  @override
  Future<bool> merge(String key, Map<K, V> entries, {bool overwrite = true}) {
    final additions = Map<K, V>.of(entries);

    return _modify(key, (map) {
      for (final entry in additions.entries) {
        if (overwrite || !map.containsKey(entry.key)) {
          map[entry.key] = entry.value;
        }
      }
    });
  }

  @override
  int? length(String key) => get(key)?.length;

  @override
  List<K>? keys(String key) {
    final map = get(key);
    if (map == null) return null;

    return List<K>.unmodifiable(map.keys);
  }

  @override
  List<V>? values(String key) {
    final map = get(key);
    if (map == null) return null;

    return List<V>.unmodifiable(map.values);
  }

  @override
  Future<int?> removeWhere(String key, bool Function(K entryKey, V value) test) async {
    int? removedCount;

    final exists = await _modify(key, (map) {
      final originalLength = map.length;
      map.removeWhere(test);
      removedCount = originalLength - map.length;
    });

    return exists ? removedCount : null;
  }

  Future<bool> _modify(String key, void Function(Map<K, V> map) operation) {
    return update(key, (current) {
      final updated = Map<K, V>.of(current);
      operation(updated);
      return updated;
    });
  }
}
