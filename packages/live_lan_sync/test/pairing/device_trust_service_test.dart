import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

import '../support/memory_stores.dart';

void main() {
  final pairedAt = DateTime.utc(2026, 11, 3, 12);
  final fingerprint = 'sha256:${'ab' * 32}';

  Future<(DeviceTrustService, MemoryLanSyncStore, MemoryCredentialStore)> service({bool paired = true}) async {
    final store = MemoryLanSyncStore();
    final credentials = MemoryCredentialStore();
    if (paired) {
      await store.putDeviceTrust(
        DeviceTrust(
          deviceId: 'device-b',
          keyFingerprint: fingerprint,
          displayName: 'Phone',
          pairedAt: pairedAt,
          readScopes: const {'favorites'},
        ),
      );
      await credentials.write(SecureKey.peerPairing('device-b'), List<int>.filled(32, 1));
    }
    return (DeviceTrustService(store: store, credentials: credentials, now: () => pairedAt), store, credentials);
  }

  group('verifyPeerIdentity', () {
    test('the paired certificate passes and stamps verification', () async {
      final (trust, store, _) = await service();
      await trust.verifyPeerIdentity(peerDeviceId: 'device-b', presentedFingerprint: 'AB' * 32);
      expect((await store.deviceTrust('device-b'))!.lastVerifiedAt, pairedAt);
    });

    test('an unpaired device is an authentication failure', () async {
      final (trust, _, _) = await service(paired: false);
      await expectLater(
        trust.verifyPeerIdentity(peerDeviceId: 'device-b', presentedFingerprint: fingerprint),
        throwsA(
          isA<LanSyncError>()
              .having((e) => e.category, 'category', LanSyncErrorCategory.authentication)
              .having((e) => e.retryable, 'retryable', isFalse),
        ),
      );
    });

    test('a changed certificate is an identity mismatch, never an update', () async {
      final (trust, store, _) = await service();
      await expectLater(
        trust.verifyPeerIdentity(peerDeviceId: 'device-b', presentedFingerprint: 'sha256:${'cd' * 32}'),
        throwsA(isA<LanSyncError>().having((e) => e.category, 'category', LanSyncErrorCategory.identityMismatch)),
      );
      expect((await store.deviceTrust('device-b'))!.keyFingerprint, fingerprint);
    });
  });

  group('updateGrants', () {
    test('changes the grants of a paired device', () async {
      final (trust, store, _) = await service();
      final updated = await trust.updateGrants(
        'device-b',
        writeScopes: const {'settings'},
        filePermissions: const {DeviceFilePermission.send, DeviceFilePermission.receive},
      );
      expect(updated.readScopes, {'favorites'}, reason: 'untouched grants are kept');
      expect(updated.writeScopes, {'settings'});
      expect((await store.deviceTrust('device-b'))!.allowsReceiveFiles, isTrue);
    });

    test('refuses an unknown device', () async {
      final (trust, _, _) = await service(paired: false);
      await expectLater(
        trust.updateGrants('device-b'),
        throwsA(isA<LanSyncError>().having((e) => e.category, 'category', LanSyncErrorCategory.permissionDenied)),
      );
    });
  });

  group('revokeDevice', () {
    test('keeps the record, kills the grants, wipes the secret', () async {
      final (trust, store, credentials) = await service();
      final revoked = await trust.revokeDevice('device-b');
      expect(revoked!.revoked, isTrue);
      expect((await store.deviceTrust('device-b'))!.allowsRead('favorites'), isFalse);
      expect(await credentials.read(SecureKey.peerPairing('device-b')), isNull);
      await expectLater(
        trust.verifyPeerIdentity(peerDeviceId: 'device-b', presentedFingerprint: fingerprint),
        throwsA(isA<LanSyncError>()),
      );
    });

    test('an unknown device revokes to null', () async {
      final (trust, _, _) = await service(paired: false);
      expect(await trust.revokeDevice('device-b'), isNull);
    });
  });
}
