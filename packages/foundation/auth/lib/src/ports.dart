// Module: lib/src/ports.dart
// Purpose: The two storage seams auth needs, declared here so foundation packages stay flat.
// Author: liuchuancong
// Created: 2026-10-08
//
// docs/architecture/dependency-rules.md section 3 forbids one L0 package depending on another (only the
// utils and logging leaves are shared), so auth cannot import pure_live_storage. It declares the narrow
// port it actually uses instead, and the composition root adapts the real backend to it. That keeps the
// dependency graph flat and stops auth from being able to read anything the store exposes beyond these
// four operations.

/// Reads and writes secrets. The application binds this to platform secure storage.
abstract interface class SecretVault {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);

  Future<List<String>> keys();
}

/// Reads and writes non-secret session state. Values are maps, lists, strings, numbers or bools.
abstract interface class SessionBox {
  Future<Object?> read(String key);

  Future<void> write(String key, Object? value);

  Future<void> remove(String key);

  Future<List<String>> keys();
}

/// An in-memory [SecretVault]. Real deployments bind the platform implementation; this one exists so a
/// test can assert on the credential lifecycle without a keystore.
final class MemorySecretVault implements SecretVault {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<List<String>> keys() async => _values.keys.toList(growable: false);
}

/// An in-memory [SessionBox].
final class MemorySessionBox implements SessionBox {
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
}
