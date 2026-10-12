import 'package:live_storage/src/repository/hive_storage_repository.dart';
import 'package:live_storage/src/repository/storage_num_repository.dart';

/// Implements numeric storage operations using Hive CE.
final class HiveStorageNumRepository extends HiveStorageRepository<num> implements StorageNumRepository {
  /// Creates a numeric repository backed by an already-open Hive CE box.
  new({required super.box});

  @override
  Future<num?> add(String key, num amount) {
    return _updateNumber(key, (current) => current + amount);
  }

  @override
  Future<num?> subtract(String key, num amount) {
    return _updateNumber(key, (current) => current - amount);
  }

  @override
  Future<num?> multiply(String key, num factor) {
    return _updateNumber(key, (current) => current * factor);
  }

  @override
  Future<num?> divide(String key, num divisor) {
    if (divisor == 0) {
      throw ArgumentError.value(divisor, 'divisor', 'Must not be zero.');
    }

    return _updateNumber(key, (current) => current / divisor);
  }

  @override
  Future<num?> increment(String key) {
    return add(key, 1);
  }

  @override
  Future<num?> decrement(String key) {
    return subtract(key, 1);
  }

  @override
  Future<num?> setMax(String key, num value) {
    return _updateNumber(key, (current) => current > value ? current : value);
  }

  @override
  Future<num?> setMin(String key, num value) {
    return _updateNumber(key, (current) => current < value ? current : value);
  }

  Future<num?> _updateNumber(String key, num Function(num current) operation) async {
    num? result;

    final updated = await update(key, (current) {
      result = operation(current);
      return result!;
    });

    return updated ? result : null;
  }
}
