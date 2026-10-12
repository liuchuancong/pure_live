import 'dart:async';

/// Defines the common contract for keyed storage repositories.
///
/// Stored values must be non-null. A null result indicates that an entry
/// does not exist.
abstract interface class StorageRepository<T extends Object> {
  /// Emits after a committed change; watching a [key] filters the
  /// stream to that key.
  Stream<void> watch({String? key});

  /// Saves a value under the specified key.
  Future<void> save(String key, T value);

  /// Saves multiple values under their respective keys.
  Future<void> saveAll(Map<String, T> values);

  /// Returns the value associated with [key].
  ///
  /// Returns null when the key does not exist.
  T? get(String key);

  /// Returns existing values for the specified keys.
  ///
  /// Missing keys are omitted from the result.
  Map<String, T> getMany(Iterable<String> keys);

  /// Returns a snapshot of all stored values.
  List<T> getAll();

  /// Returns a snapshot of all stored entries.
  Map<String, T> getAllEntries();

  /// Returns a snapshot of all stored keys.
  List<String> getAllKeys();

  /// Whether the specified key exists.
  bool contains(String key);

  /// Whether all specified keys exist.
  bool containsAll(Iterable<String> keys);

  /// Inserts [value] only when [key] does not exist.
  ///
  /// Returns true when the value is inserted.
  ///
  /// Implementations must define the concurrency guarantees of this operation.
  Future<bool> insertIfAbsent(String key, T value);

  /// Updates an existing value using [updater].
  ///
  /// Returns true when the value exists and is updated.
  /// Returns false when the key does not exist.
  ///
  /// Implementations must define the concurrency guarantees of this operation.
  /// The updater must be synchronous and should not perform storage operations
  /// on the same repository.
  Future<bool> update(String key, T Function(T current) updater);

  /// Deletes the entry associated with [key].
  Future<void> delete(String key);

  /// Deletes entries associated with [keys].
  Future<void> deleteAll(Iterable<String> keys);

  /// Deletes entries matching [test].
  ///
  /// Returns the number of deleted entries.
  Future<int> deleteWhere(bool Function(String key, T value) test);

  /// Returns the number of stored entries.
  int get count;

  /// Whether the repository contains no entries.
  bool get isEmpty;

  /// Whether the repository contains at least one entry.
  bool get isNotEmpty;

  /// Deletes all entries.
  Future<void> clear();

  /// Flushes pending storage writes.
  Future<void> flush();
}
