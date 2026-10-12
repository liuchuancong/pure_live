import 'package:live_storage/src/repository/storage_repository.dart';

/// Defines string-specific operations for a storage repository.
abstract interface class StorageStringRepository implements StorageRepository<String> {
  /// Appends [suffix] to the existing string.
  ///
  /// Returns false when the key does not exist.
  Future<bool> append(String key, String suffix);

  /// Prepends [prefix] to the existing string.
  ///
  /// Returns false when the key does not exist.
  Future<bool> prepend(String key, String prefix);

  /// Replaces the existing string with [value] when the key exists.
  ///
  /// Returns false when the key does not exist.
  Future<bool> replace(String key, String value);

  /// Returns the length of the stored string.
  ///
  /// Returns null when the key does not exist.
  int? length(String key);

  /// Returns whether the stored string starts with [prefix].
  ///
  /// Returns false when the key does not exist.
  bool startsWith(String key, String prefix);

  /// Returns whether the stored string ends with [suffix].
  ///
  /// Returns false when the key does not exist.
  bool endsWith(String key, String suffix);

  /// Returns whether the stored string contains [pattern].
  ///
  /// Returns false when the key does not exist.
  bool containsText(String key, String pattern);

  /// Returns a trimmed copy of the stored string.
  ///
  /// Returns null when the key does not exist.
  String? trimValue(String key);
}
