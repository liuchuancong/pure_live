import 'dart:convert' show base64Decode, base64Encode;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:live_lan_sync/live_lan_sync.dart';

/// The engine's secret vault over `flutter_secure_storage` — the same
/// platform backing the account credentials use (Windows DPAPI, the iOS
/// Keychain, the Android Keystore).
///
/// Bytes are stored base64-encoded; the plugin's values are strings.
final class SecureVaultCredentialStore implements SecureCredentialStore {
  /// The store; the plugin carries its own platform options.
  const SecureVaultCredentialStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  String _key(SecureKey key) => 'lan_sync.${key.id}';

  @override
  Future<void> write(SecureKey key, List<int> bytes) => _storage.write(key: _key(key), value: base64Encode(bytes));

  @override
  Future<List<int>?> read(SecureKey key) async {
    final value = await _storage.read(key: _key(key));
    return value == null || value.isEmpty ? null : base64Decode(value);
  }

  @override
  Future<void> delete(SecureKey key) => _storage.delete(key: _key(key));
}
