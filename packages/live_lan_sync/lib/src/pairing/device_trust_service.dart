import 'package:live_lan_sync/src/domain/device/device.dart' show DeviceFilePermission, DeviceTrust;
import 'package:live_lan_sync/src/domain/errors/errors.dart' show LanSyncError, LanSyncErrorCategory;
import 'package:live_lan_sync/src/pairing/fingerprint.dart' show KeyFingerprints;
import 'package:live_lan_sync/src/security/secure_credential_store.dart' show SecureCredentialStore, SecureKey;
import 'package:live_lan_sync/src/store/store.dart' show LanSyncStore;

/// Manages trust after pairing: identity checks, grant changes and
/// revocation (spec §9.4, §20).
///
/// The ceremony that *creates* trust lives in `PairingResponder` and
/// `PairingInitiator`; this service owns everything that happens to a
/// trust record afterwards.
final class DeviceTrustService {
  /// A trust service over the given stores.
  new({required this.store, required this.credentials, DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// The persistence every trust decision goes through.
  final LanSyncStore store;

  /// The secure storage for secret material; revocation wipes here.
  final SecureCredentialStore credentials;

  final DateTime Function() _now;

  /// Verifies the identity a paired peer presents: its TLS certificate
  /// fingerprint must match the paired record exactly. A success stamps
  /// `lastVerifiedAt`.
  ///
  /// Throws a [LanSyncError] with `authentication` for an unpaired or
  /// revoked device and `identityMismatch` for a changed certificate — both
  /// never retryable.
  Future<void> verifyPeerIdentity({required String peerDeviceId, required String presentedFingerprint}) async {
    final trust = await store.deviceTrust(peerDeviceId);
    if (trust == null || trust.revoked) {
      throw LanSyncError(
        category: LanSyncErrorCategory.authentication,
        code: 'peer_not_paired',
        message: 'The device is not paired, or the pairing was revoked.',
        deviceId: peerDeviceId,
      );
    }
    final normalized = KeyFingerprints.normalize(presentedFingerprint);
    if (normalized == null || !KeyFingerprints.secureEquals(normalized, trust.keyFingerprint)) {
      throw LanSyncError(
        category: LanSyncErrorCategory.identityMismatch,
        code: 'peer_key_changed',
        message: 'The device presented a different certificate than when it was paired.',
        deviceId: peerDeviceId,
      );
    }
    await store.putDeviceTrust(
      DeviceTrust(
        deviceId: trust.deviceId,
        keyFingerprint: trust.keyFingerprint,
        displayName: trust.displayName,
        pairedAt: trust.pairedAt,
        lastVerifiedAt: _now(),
        readScopes: trust.readScopes,
        writeScopes: trust.writeScopes,
        filePermissions: trust.filePermissions,
        canInitiateSync: trust.canInitiateSync,
        canAcceptSync: trust.canAcceptSync,
      ),
    );
  }

  /// Updates the grants of an already paired device, user-driven.
  ///
  /// Throws a [LanSyncError] with `permissionDenied` when the device is not
  /// paired.
  Future<DeviceTrust> updateGrants(
    String peerDeviceId, {
    Set<String>? readScopes,
    Set<String>? writeScopes,
    Set<DeviceFilePermission>? filePermissions,
    bool? canInitiateSync,
    bool? canAcceptSync,
  }) async {
    final trust = await store.deviceTrust(peerDeviceId);
    if (trust == null || trust.revoked) {
      throw LanSyncError(
        category: LanSyncErrorCategory.permissionDenied,
        code: 'peer_not_paired',
        message: 'Grants can only change on a paired device.',
        deviceId: peerDeviceId,
      );
    }
    final updated = DeviceTrust(
      deviceId: trust.deviceId,
      keyFingerprint: trust.keyFingerprint,
      displayName: trust.displayName,
      pairedAt: trust.pairedAt,
      lastVerifiedAt: trust.lastVerifiedAt,
      readScopes: readScopes ?? trust.readScopes,
      writeScopes: writeScopes ?? trust.writeScopes,
      filePermissions: filePermissions ?? trust.filePermissions,
      canInitiateSync: canInitiateSync ?? trust.canInitiateSync,
      canAcceptSync: canAcceptSync ?? trust.canAcceptSync,
    );
    await store.putDeviceTrust(updated);
    return updated;
  }

  /// Revokes a device: the trust record is kept (so a reconnecting peer is
  /// refused with an explicit reason and its tombstones still suppress
  /// resurrection), its pairing secret is wiped from secure storage — every
  /// signed request it makes fails from now on — and every grant is dropped.
  ///
  /// Returns the revoked record, or null when the device was never paired.
  Future<DeviceTrust?> revokeDevice(String peerDeviceId) async {
    final trust = await store.deviceTrust(peerDeviceId);
    if (trust == null) return null;
    final revoked = trust.revoke();
    await store.putDeviceTrust(revoked);
    await credentials.delete(SecureKey.peerPairing(peerDeviceId));
    return revoked;
  }
}
