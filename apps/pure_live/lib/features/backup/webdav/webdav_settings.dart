import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:live_storage/live_storage.dart';

/// Where the WebDAV settings persist: the address and the username are
/// plain prefs, the password never leaves the vault.
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

/// What the WebDAV settings hold: the address and username as stored (and
/// as the dialog edits them), and whether a password hides in the vault.
typedef WebDavSettings = ({String url, String user, bool hasPassword});

/// Owns the WebDAV settings the backup pane edits.
///
/// The address and username write through to their prefs at once; the
/// password goes to the vault whole (set, keep or clear) — [save] is the
/// one write path, so a half-committed dialog never lands.
final class WebDavSettingsController extends Notifier<WebDavSettings> {
  @override
  WebDavSettings build() {
    // The secret store loads from the device vault; until it does, the
    // password badge reads "not set" and rights itself when the load
    // lands (an unsupported platform keeps it there, and every action
    // still works with an empty password).
    final store = ref.watch(webdavSecretStoreProvider).value;
    return (
      url: _stored(kWebDavUrlPref),
      user: _stored(kWebDavUserPref),
      hasPassword: store?.contains(SecretRefs.webdav(kWebDavVault)) ?? false,
    );
  }

  static String _stored(String key) {
    try {
      return StoragePrefs.getString(key) ?? '';
    } on Object {
      return '';
    }
  }

  /// Commits the dialog: [url] and [user] become the stored values;
  /// [password] == null keeps the stored one, empty clears it, anything
  /// else replaces it in the vault.
  Future<void> save({required String url, required String user, String? password}) async {
    final nextUrl = url.trim();
    final nextUser = user.trim();
    state = (url: nextUrl, user: nextUser, hasPassword: state.hasPassword);
    try {
      await StoragePrefs.setString(kWebDavUrlPref, nextUrl);
      await StoragePrefs.setString(kWebDavUserPref, nextUser);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
    if (password != null) {
      final store = await _store();
      if (store != null) {
        if (password.isEmpty) {
          await store.remove(SecretRefs.webdav(kWebDavVault));
        } else {
          await store.set(SecretRefs.webdav(kWebDavVault), password);
        }
      }
      state = (url: state.url, user: state.user, hasPassword: password.isNotEmpty);
    }
  }

  /// The loaded secret store, or null when the vault never opened.
  Future<SecretStore?> _store() async {
    try {
      return await ref.read(webdavSecretStoreProvider.future);
    } on Object {
      return null;
    }
  }
}

/// The WebDAV settings.
final webdavSettingsProvider = NotifierProvider<WebDavSettingsController, WebDavSettings>(WebDavSettingsController.new);
