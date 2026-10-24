import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:live_sites/live_sites.dart' show LiveCredential;
import 'package:live_storage/live_storage.dart' show SecretStore, SecretVault;

/// The device's secret vault over `flutter_secure_storage` — the
/// implementation the storage package leaves to the app shell (Windows
/// DPAPI, the iOS Keychain, the Android Keystore).
final class SecureVaultAdapter implements SecretVault {
  /// The adapter; the plugin carries its own platform options.
  const SecureVaultAdapter();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<void> write(String ref, String plain) => _storage.write(key: ref, value: plain);

  @override
  Future<void> delete(String ref) => _storage.delete(key: ref);
}

/// The viewer's platform credentials over the app's [SecretStore]: one
/// JSON document per signed-in site, never on disk in plain text. The
/// refs live under `credentials/<siteId>` — the app's vault namespace for
/// login credentials — and every read is a memory read off the store's
/// cache.
final class AccountRepository {
  AccountRepository._(this._store);

  static const String _refPrefix = 'credentials/';

  /// The secret store this repository reads and writes.
  final SecretStore _store;

  /// Opens the repository: loads every stored secret into the store's
  /// memory cache once.
  static Future<AccountRepository> open() async =>
      AccountRepository._(await SecretStore.load(vault: const SecureVaultAdapter()));

  /// Emits after every committed credential change under the
  /// repository's namespace.
  Stream<void> watch() => _store.changes.where((ref) => ref.startsWith(_refPrefix));

  /// The stored credentials, keyed by site id.
  Map<String, LiveCredential> list() {
    final credentials = <String, LiveCredential>{};
    for (final ref in _store.refs) {
      if (!ref.startsWith(_refPrefix)) continue;
      final credential = _decode(_store.value(ref));
      if (credential != null) credentials[credential.siteId] = credential;
    }
    return credentials;
  }

  /// The stored credential of [siteId], or null.
  LiveCredential? get(String siteId) => _decode(_store.value(_ref(siteId)));

  /// Stores [credential], replacing its site's previous entry.
  Future<void> save(LiveCredential credential) => _store.set(_ref(credential.siteId), jsonEncode(_encode(credential)));

  /// Drops [siteId]'s credential; a never-stored site is a no-op.
  Future<void> remove(String siteId) => _store.remove(_ref(siteId));

  static String _ref(String siteId) => '$_refPrefix${siteId.trim().toLowerCase()}';

  static Map<String, Object?> _encode(LiveCredential credential) => <String, Object?>{
    'siteId': credential.siteId,
    'cookies': credential.cookies,
    if (credential.userId != null) 'userId': credential.userId,
    if (credential.nickname != null) 'nickname': credential.nickname,
    if (credential.avatar != null) 'avatar': credential.avatar,
    if (credential.expiry != null) 'expiry': credential.expiry!.toIso8601String(),
  };

  static LiveCredential? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final cookies = json['cookies'];
      if (cookies is! Map) return null;
      return LiveCredential(
        siteId: json['siteId'] as String,
        cookies: {for (final entry in cookies.entries) '${entry.key}': '${entry.value}'},
        userId: json['userId'] as String?,
        nickname: json['nickname'] as String?,
        avatar: json['avatar'] as String?,
        expiry: json['expiry'] is String ? DateTime.tryParse(json['expiry'] as String) : null,
      );
    } on Object {
      // A credential the app cannot read is as good as absent; the next
      // sign-in replaces it.
      return null;
    }
  }
}
