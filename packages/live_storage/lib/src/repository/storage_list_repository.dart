import 'package:live_storage/src/repository/storage_repository.dart';

/// Defines list-specific operations for a storage repository.
abstract interface class StorageListRepository<E> implements StorageRepository<List<E>> {
  /// Appends [value] to the list stored under [key].
  ///
  /// Returns false when the key does not exist.
  Future<bool> append(String key, E value);

  /// Appends all [values] to the list stored under [key].
  ///
  /// Returns false when the key does not exist.
  Future<bool> appendAll(String key, Iterable<E> values);

  /// Inserts [value] at [index] in the list stored under [key].
  ///
  /// Returns false when the key does not exist.
  /// Throws [RangeError] when [index] is out of range.
  Future<bool> insert(String key, int index, E value);

  /// Removes the first matching [value] from the stored list.
  ///
  /// Returns false when the key does not exist or the value is absent.
  Future<bool> remove(String key, E value);

  /// Removes the element at [index] from the stored list.
  ///
  /// Returns the removed element, or null when the key does not exist.
  /// Throws [RangeError] when [index] is out of range.
  Future<E?> removeAt(String key, int index);

  /// Replaces the element at [index] with [value].
  ///
  /// Returns false when the key does not exist.
  /// Throws [RangeError] when [index] is out of range.
  Future<bool> replaceAt(String key, int index, E value);

  /// Returns the element at [index].
  ///
  /// Returns null when the key does not exist.
  /// Throws [RangeError] when [index] is out of range.
  E? elementAt(String key, int index);

  /// Returns the number of elements in the stored list.
  ///
  /// Returns null when the key does not exist.
  int? length(String key);

  /// Returns whether the stored list contains [value].
  ///
  /// Returns false when the key does not exist.
  bool containsValue(String key, E value);

  /// Removes all elements matching [test].
  ///
  /// Returns the number of removed elements, or null when the key does not exist.
  Future<int?> removeWhere(String key, bool Function(E element) test);

  /// Sorts the stored list using the optional [compare] function.
  ///
  /// Returns false when the key does not exist.
  Future<bool> sort(String key, [int Function(E a, E b)? compare]);

  /// Reverses the stored list.
  ///
  /// Returns false when the key does not exist.
  Future<bool> reverse(String key);
}
