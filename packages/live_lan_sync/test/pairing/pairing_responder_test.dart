import 'dart:convert' show base64Url;

import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

import '../support/memory_stores.dart';
import '../support/tls_fixtures.dart';

void main() {
  const deviceA = LanSyncDeviceConfig(
    deviceId: 'device-a',
    deviceName: 'Desktop',
    platform: 'windows',
    appVersion: '4.0.0',
  );
  const security = LanSyncSecurityConfig(maxPairingAttempts: 2, maxPendingPairingSessions: 2);
  final identityA = loadTlsIdentity('device_a');

  _Harness harness() {
    final harness = _Harness();
    final pairing = PairingResponder(
      store: MemoryLanSyncStore(),
      credentials: MemoryCredentialStore(),
      security: security,
      deviceConfig: deviceA,
      tlsIdentity: identityA,
      now: () => harness.now,
    );
    harness.responder = pairing;
    addTearDown(pairing.dispose);
    return harness;
  }

  Future<Map<String, Object?>> challenge(PairingResponder pairing, {String deviceId = 'device-b'}) async {
    final keys = await PairingProtocol.newKeyPair();
    return await pairing.handleChallenge(<String, Object?>{
      'initiator': PairingParty(
        deviceId: deviceId,
        deviceName: 'Phone',
        platform: 'android',
        appVersion: '4.0.0',
        publicKey: await PairingProtocol.publicKeyOf(keys),
        tlsFingerprint: 'sha256:${'ef' * 32}',
      ).toJson(),
    }, remoteAddress: '192.168.1.9');
  }

  test('a closed window refuses challenges', () async {
    final responder = harness().responder;
    await expectLater(
      challenge(responder),
      throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'pairing_window_closed')),
    );
  });

  test('the window closes on its own', () async {
    final setup = harness();
    final responder = setup.responder..openPairingWindow(duration: const Duration(minutes: 1));
    expect(responder.isPairingWindowOpen, isTrue);
    setup.advance(const Duration(minutes: 2));
    expect(responder.isPairingWindowOpen, isFalse);
  });

  test('the challenge answers with the responder facts and a commitment', () async {
    final responder = harness().responder..openPairingWindow();
    final answer = await challenge(responder);
    final party = PairingParty.fromJson(answer['responder']! as Map<String, Object?>);
    expect(party.deviceId, 'device-a');
    expect(party.tlsFingerprint, identityA.fingerprint);
    expect(base64Url.decode(answer['commitment']! as String), hasLength(32));
    expect(answer['sessionId'], isA<String>());
  });

  test('the device cannot pair with itself', () async {
    final responder = harness().responder..openPairingWindow();
    await expectLater(
      challenge(responder, deviceId: 'device-a'),
      throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'pairing_with_self')),
    );
  });

  test('concurrent sessions are bounded', () async {
    final responder = harness().responder..openPairingWindow();
    await challenge(responder);
    await challenge(responder, deviceId: 'device-c');
    await expectLater(
      challenge(responder, deviceId: 'device-d'),
      throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'pairing_sessions_exhausted')),
    );
  });

  test('steps out of order are refused', () async {
    final responder = harness().responder..openPairingWindow();
    final answer = await challenge(responder);
    await expectLater(
      responder.handleConfirm(<String, Object?>{
        'sessionId': answer['sessionId'],
        'decision': 'accept',
        'mac': base64Url.encode(List<int>.filled(32, 0)),
      }),
      throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'pairing_step_out_of_order')),
    );
  });

  test('a wrong key confirmation fails the session and counts against the device', () async {
    final responder = harness().responder..openPairingWindow();
    for (var attempt = 0; attempt < security.maxPairingAttempts; attempt++) {
      final answer = await challenge(responder);
      await responder.handleReveal(<String, Object?>{
        'sessionId': answer['sessionId'],
        'nonce': base64Url.encode(List<int>.filled(32, attempt)),
      });
      final status = await responder.handleConfirm(<String, Object?>{
        'sessionId': answer['sessionId'],
        'decision': 'accept',
        'mac': base64Url.encode(List<int>.filled(32, 0)),
      });
      expect(status['status'], 'failed');
    }
    await expectLater(
      challenge(responder),
      throwsA(isA<LanSyncError>().having((e) => e.category, 'category', LanSyncErrorCategory.rateLimited)),
    );
  });

  test('a session lapses after its lifetime', () async {
    final setup = harness();
    final responder = setup.responder..openPairingWindow();
    final answer = await challenge(responder);
    setup.advance(security.pairingCodeTtl + const Duration(seconds: 1));
    await expectLater(
      responder.handleReveal(<String, Object?>{
        'sessionId': answer['sessionId'],
        'nonce': base64Url.encode(List<int>.filled(32, 1)),
      }),
      throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'pairing_session_expired')),
    );
    expect(responder.handleStatus(<String, Object?>{'sessionId': answer['sessionId']})['status'], 'expired');
  });

  test('accepting an unknown session fails cleanly', () async {
    final responder = harness().responder;
    final outcome = await responder.accept('nope');
    expect(outcome, isA<PairingFailed>());
    expect((outcome as PairingFailed).reason, PairingFailureReason.unknownSession);
  });

  test('malformed messages are data validation errors', () async {
    final responder = harness().responder..openPairingWindow();
    await expectLater(
      responder.handleChallenge(<String, Object?>{'initiator': 'nope'}, remoteAddress: '192.168.1.9'),
      throwsA(isA<LanSyncError>().having((e) => e.category, 'category', LanSyncErrorCategory.dataValidation)),
    );
  });
}

final class _Harness {
  DateTime now = DateTime.utc(2026, 11, 3, 12);
  late final PairingResponder responder;

  void advance(Duration by) => now = now.add(by);
}
