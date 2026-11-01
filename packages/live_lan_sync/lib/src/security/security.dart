/// Secret material and the device's TLS identity.
///
/// Trust metadata (fingerprints, grants) lives in the host's `LanSyncStore`
/// — it is not secret. Key material itself (the TLS private key, per-peer
/// pairing secrets) must never rest in a plain database; the host plugs a
/// `SecureCredentialStore` backed by the platform vault (Windows DPAPI, iOS
/// Keychain, Android Keystore, libsecret) (spec §19.6, §20).
library;

export 'secure_credential_store.dart';
export 'tls_identity.dart';
