import 'dart:async';

/// A store for credentials: tokens, sensitive cookies, keys.
///
/// The interface is deliberately minimal and string-typed; the backing
/// technology (Keystore, Keychain, DPAPI, libsecret) is an app-shell
/// concern injected here. Values must never appear in logs, crash
/// reports or ordinary backups.
///
/// Do not assume every desktop platform offers identical guarantees —
/// the app shell decides which backend is trustworthy on its platforms.
abstract interface class SecureStore {
  /// Reads the secret under [key], or null when absent.
  Future<String?> read(String key);

  /// Writes [value] under [key], overwriting any previous secret.
  Future<void> write(String key, String value);

  /// Removes [key]; a no-op when absent.
  Future<void> delete(String key);

  /// Whether a secret exists under [key].
  Future<bool> contains(String key);

  /// Removes every secret. Used by logout and credential-wipe flows.
  Future<void> clear();
}
