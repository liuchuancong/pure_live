import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:live_storage/live_storage.dart';

/// The two prefs the builds before the account list stored a single server
/// in. They are the migration's source now (`webdav_accounts.dart`) and stay
/// named here because the vault's own name is beside them: the password never
/// leaves the vault.
const String kWebDavUrlPref = 'backup.webdav.url';
const String kWebDavUserPref = 'backup.webdav.user';

/// The vault name the WebDAV password hides under (`SecretRefs.webdav`).
const String kWebDavVault = 'webdav';

/// The device's secret vault: [SecretVault] over flutter_secure_storage —
/// the Android Keystore, the iOS Keychain or Windows DPAPI underneath.
///
/// The app shell owns no vault of its own yet (cookies ride their site
/// adapters), so the backup feature provides this one; a later shell-level
/// vault can replace the provider below without touching a caller.
final class SecureVault implements SecretVault {
  /// The vault over [storage].
  const SecureVault(this.storage);

  final FlutterSecureStorage storage;

  @override
  Future<Map<String, String>> readAll() => storage.readAll();

  @override
  Future<void> write(String ref, String plain) => storage.write(key: ref, value: plain);

  @override
  Future<void> delete(String ref) => storage.delete(key: ref);
}

/// The app's secrets, cached in memory over the device vault. The WebDAV
/// password is read through this, never through the prefs.
final webdavSecretStoreProvider = FutureProvider<SecretStore>((ref) {
  return SecretStore.load(vault: const SecureVault(FlutterSecureStorage()));
});

/// The device vault, read through a widget's ref; null when it never opened.
///
/// The account list and every page that shows a password badge goes through
/// this, so an unsupported platform or a locked keychain reads as "no secret
/// stored" instead of hanging on a future that never lands. (The controller
/// side has its own copy of the two-line read: a `Notifier` holds a `Ref`, not
/// a `WidgetRef`.)
Future<SecretStore?> webDavVault(WidgetRef ref) async {
  try {
    return await ref.read(webdavSecretStoreProvider.future);
  } on Object {
    return null;
  }
}
