import 'package:live_storage/src/repository/storage_repository.dart';

/// Defines numeric operations for a storage repository.
abstract interface class StorageNumRepository implements StorageRepository<num> {
  /// Adds [amount] to the existing numeric value.
  ///
  /// Returns the updated value, or null when the key does not exist.
  Future<num?> add(String key, num amount);

  /// Subtracts [amount] from the existing numeric value.
  ///
  /// Returns the updated value, or null when the key does not exist.
  Future<num?> subtract(String key, num amount);

  /// Multiplies the existing numeric value by [factor].
  ///
  /// Returns the updated value, or null when the key does not exist.
  Future<num?> multiply(String key, num factor);

  /// Divides the existing numeric value by [divisor].
  ///
  /// Returns the updated value, or null when the key does not exist.
  ///
  /// Throws [ArgumentError] when [divisor] is zero.
  Future<num?> divide(String key, num divisor);

  /// Increments the existing numeric value by one.
  ///
  /// Returns the updated value, or null when the key does not exist.
  Future<num?> increment(String key);

  /// Decrements the existing numeric value by one.
  ///
  /// Returns the updated value, or null when the key does not exist.
  Future<num?> decrement(String key);

  /// Replaces the existing value when it is less than [value].
  ///
  /// Returns the resulting value, or null when the key does not exist.
  Future<num?> setMax(String key, num value);

  /// Replaces the existing value when it is greater than [value].
  ///
  /// Returns the resulting value, or null when the key does not exist.
  Future<num?> setMin(String key, num value);
}
