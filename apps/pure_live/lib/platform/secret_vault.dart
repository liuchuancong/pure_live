import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:live_storage/live_storage.dart';

/// The device's [SecretVault] over flutter_secure_storage: the Android
/// Keystore, the iOS Keychain or Windows DPAPI, per platform.
final class SecureStorageSecretVault implements SecretVault {
/// Creates the vault over [storage].
// ignore: prefer_initializing_formals
new({FlutterSecureStorage storage = const FlutterSecureStorage()}) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<void> write(String ref, String plain) => _storage.write(key: ref, value: plain);

  @override
  Future<void> delete(String ref) => _storage.delete(key: ref);
}
