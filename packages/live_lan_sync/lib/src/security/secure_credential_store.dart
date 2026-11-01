import 'package:meta/meta.dart';

/// Names a piece of secret material inside a [SecureCredentialStore].
///
/// Keys are namespaced so hosts can map them onto whatever their platform
/// vault keys look like. Two well-known keys exist: this device's own
/// identity material, and the per-peer pairing secret.
@immutable
final class SecureKey {
  /// The key named [id]. Prefer the named factories below.
  const new(this.id);

  /// This device's own identity key material.
  factory localIdentity() => const SecureKey('identity/self');

  /// The pairing secret shared with [deviceId].
  factory peerPairing(String deviceId) => SecureKey('pairing/$deviceId');

  /// The stable id, unique within one store.
  final String id;

  @override
  bool operator ==(Object other) => other is SecureKey && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SecureKey($id)';
}

/// Secrets in, secrets out — nothing else knows where they sleep.
abstract interface class SecureCredentialStore {
  /// Persists [bytes] under [key], replacing any previous value.
  Future<void> write(SecureKey key, List<int> bytes);

  /// The bytes stored under [key], or null when absent.
  Future<List<int>?> read(SecureKey key);

  /// Removes the value under [key], if any.
  Future<void> delete(SecureKey key);
}
