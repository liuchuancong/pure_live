import 'dart:async';
import 'dart:collection';

import 'package:live_storage/src/contracts/secure_store.dart';

/// [SecureStore] over a plain map — for tests and dependency-free
/// development runs.
///
/// Real deployments must inject a Keychain/Keystore/DPAPI-backed
/// implementation at the app shell; this class never touches durable
/// storage, so secrets held here vanish with the process.
final class InMemorySecureStore implements SecureStore {
  /// An empty store.
  new();

  final HashMap<String, String> _values = HashMap<String, String>();

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<bool> contains(String key) async => _values.containsKey(key);

  @override
  Future<void> clear() async {
    _values.clear();
  }
}
