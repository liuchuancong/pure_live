// Module: lib/src/stores.dart
// Purpose: Key-value and secret storage interfaces plus in-memory implementations the rest of the platform codes against.
// Author: liuchuancong
// Created: 2026-10-08
//
// The app binds these to real backends (a database, flutter_secure_storage) from the composition root.
// Keeping the interface in foundation is what lets a repository, a service or a test run without Flutter.

/// A persistent store of string keys to simple values.
abstract interface class KeyValueStore {
  Future<Object?> read(String key);

  Future<void> write(String key, Object? value);

  Future<void> remove(String key);

  /// All keys currently present. Namespaced callers should filter with [keysUnder].
  Future<List<String>> keys();

  Future<void> clear();
}

/// Reads and writes secrets. Implementations must use platform secure storage, never a plain file.
abstract interface class SecureStore {
  Future<String?> readSecret(String key);

  Future<void> writeSecret(String key, String value);

  Future<void> removeSecret(String key);

  Future<List<String>> secretKeys();
}

/// Typed reads that keep the "absent" and "wrong type" cases distinct.
extension KeyValueStoreRead on KeyValueStore {
  /// The stored string, or [fallback] when absent or not a string.
  Future<String> readString(String key, {String fallback = ''}) async {
    final value = await read(key);
    return value is String ? value : fallback;
  }

  /// The stored boolean, or [fallback] when absent or not a bool.
  Future<bool> readBool(String key, {bool fallback = false}) async {
    final value = await read(key);
    return value is bool ? value : fallback;
  }

  /// The stored integer, or [fallback]. A string that parses as an int is accepted because older stores
  /// persisted numbers as text.
  Future<int> readInt(String key, {int fallback = 0}) async {
    final value = await read(key);
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  Future<double> readDouble(String key, {double fallback = 0}) async {
    final value = await read(key);
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }
}

/// Keys are grouped by a leading `namespace.` segment; this filters them.
List<String> keysUnder(Iterable<String> keys, String namespace) {
  final prefix = '$namespace.';
  return keys.where((key) => key.startsWith(prefix)).toList(growable: false);
}

/// An in-memory [KeyValueStore] for tests, defaults and transient sessions.
final class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, Object?> _values = <String, Object?>{};

  @override
  Future<Object?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, Object? value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<List<String>> keys() async => _values.keys.toList(growable: false);

  @override
  Future<void> clear() async => _values.clear();
}

/// An in-memory [SecureStore]. Tests only: it holds secrets in plain memory by design.
final class MemorySecureStore implements SecureStore {
  final Map<String, String> _secrets = <String, String>{};

  @override
  Future<String?> readSecret(String key) async => _secrets[key];

  @override
  Future<void> writeSecret(String key, String value) async {
    _secrets[key] = value;
  }

  @override
  Future<void> removeSecret(String key) async {
    _secrets.remove(key);
  }

  @override
  Future<List<String>> secretKeys() async => _secrets.keys.toList(growable: false);
}
