import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:live_storage/live_storage.dart';

/// The device secret vault the app's [SecretStore] caches over:
/// flutter_secure_storage's platform-backed store (DPAPI on Windows, the
/// Keychain on macOS, the Keystore on Android).
///
/// The composition root does not open storage through this type — the vault
/// is stateless over one platform store, so the login feature constructs it
/// where its repository first needs it and every later read hits the store's
/// in-memory cache anyway.
final class SecureVault implements SecretVault {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<void> write(String ref, String plain) => _storage.write(key: ref, value: plain);

  @override
  Future<void> delete(String ref) => _storage.delete(key: ref);
}
