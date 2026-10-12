import 'package:live_storage/src/repository/hive_storage_repository.dart';
import 'package:live_storage/src/repository/storage_string_repository.dart';

/// Implements string-specific storage operations using Hive CE.
final class HiveStorageStringRepository extends HiveStorageRepository<String> implements StorageStringRepository {
  /// Creates a string repository backed by an already-open Hive CE box.
  new({required super.box});

  @override
  Future<bool> append(String key, String suffix) {
    return update(key, (current) => '$current$suffix');
  }

  @override
  Future<bool> prepend(String key, String prefix) {
    return update(key, (current) => '$prefix$current');
  }

  @override
  Future<bool> replace(String key, String value) {
    return update(key, (_) => value);
  }

  @override
  int? length(String key) => get(key)?.length;

  @override
  bool startsWith(String key, String prefix) {
    return get(key)?.startsWith(prefix) ?? false;
  }

  @override
  bool endsWith(String key, String suffix) {
    return get(key)?.endsWith(suffix) ?? false;
  }

  @override
  bool containsText(String key, String pattern) {
    return get(key)?.contains(pattern) ?? false;
  }

  @override
  String? trimValue(String key) => get(key)?.trim();
}
