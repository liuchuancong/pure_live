import 'package:live_storage/src/repository/storage_repository.dart';

/// Defines map-specific operations for a storage repository.
abstract interface class StorageMapRepository<K, V> implements StorageRepository<Map<K, V>> {
  /// Sets [value] for [mapKey] in the stored map.
  ///
  /// Returns false when the storage entry does not exist.
  Future<bool> setEntry(String key, K mapKey, V value);

  /// Sets multiple entries in the stored map.
  ///
  /// Existing entries are overwritten.
  /// Returns false when the storage entry does not exist.
  Future<bool> setEntries(String key, Map<K, V> entries);

  /// Returns the value associated with [mapKey].
  ///
  /// Returns null when the storage entry or map key does not exist.
  V? getEntry(String key, K mapKey);

  /// Returns whether [mapKey] exists in the stored map.
  ///
  /// Returns false when the storage entry does not exist.
  bool containsEntry(String key, K mapKey);

  /// Removes [mapKey] from the stored map.
  ///
  /// Returns false when the storage entry or map key does not exist.
  Future<bool> removeEntry(String key, K mapKey);

  /// Removes multiple keys from the stored map.
  ///
  /// Returns the number of removed entries, or null when the storage entry
  /// does not exist.
  Future<int?> removeEntries(String key, Iterable<K> mapKeys);

  /// Merges [entries] into the stored map.
  ///
  /// Existing values are overwritten by [entries].
  /// Returns false when the storage entry does not exist.
  Future<bool> merge(String key, Map<K, V> entries);

  /// Returns the number of entries in the stored map.
  ///
  /// Returns null when the storage entry does not exist.
  int? length(String key);

  /// Returns all keys in the stored map.
  ///
  /// Returns null when the storage entry does not exist.
  List<K>? keys(String key);

  /// Returns all values in the stored map.
  ///
  /// Returns null when the storage entry does not exist.
  List<V>? values(String key);

  /// Removes all entries matching [test].
  ///
  /// Returns the number of removed entries, or null when the storage entry
  /// does not exist.
  Future<int?> removeWhere(String key, bool Function(K mapKey, V value) test);
}
