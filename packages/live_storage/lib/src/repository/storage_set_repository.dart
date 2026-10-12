import 'package:live_storage/src/repository/storage_repository.dart';

/// Defines set-specific operations for a storage repository.
abstract interface class StorageSetRepository<E> implements StorageRepository<Set<E>> {
  /// Adds [value] to the stored set.
  ///
  /// Returns false when the storage entry does not exist or the value
  /// is already present.
  Future<bool> addValue(String key, E value);

  /// Adds all [values] to the stored set.
  ///
  /// Returns the number of newly added values, or null when the storage
  /// entry does not exist.
  Future<int?> addAllValues(String key, Iterable<E> values);

  /// Removes [value] from the stored set.
  ///
  /// Returns false when the storage entry does not exist or the value
  /// is absent.
  Future<bool> removeValue(String key, E value);

  /// Removes all [values] from the stored set.
  ///
  /// Returns the number of removed values, or null when the storage
  /// entry does not exist.
  Future<int?> removeAllValues(String key, Iterable<E> values);

  /// Returns whether the stored set contains [value].
  ///
  /// Returns false when the storage entry does not exist.
  bool containsValue(String key, E value);

  /// Returns the number of elements in the stored set.
  ///
  /// Returns null when the storage entry does not exist.
  int? length(String key);

  /// Returns all elements in the stored set.
  ///
  /// Returns null when the storage entry does not exist.
  Set<E>? values(String key);

  /// Adds all values from [other] to the stored set.
  ///
  /// Returns false when the storage entry does not exist.
  Future<bool> unionWith(String key, Set<E> other);

  /// Retains only values that are also present in [other].
  ///
  /// Returns false when the storage entry does not exist.
  Future<bool> intersectWith(String key, Set<E> other);

  /// Removes values present in [other].
  ///
  /// Returns false when the storage entry does not exist.
  Future<bool> differenceWith(String key, Set<E> other);

  /// Removes all elements matching [test].
  ///
  /// Returns the number of removed elements, or null when the storage
  /// entry does not exist.
  Future<int?> removeWhere(String key, bool Function(E value) test);
}
