import 'dart:math' show Random;

import 'package:cryptography/cryptography.dart' as kx;
import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

void main() {
  group('primitive test vectors', () {
    test('HKDF-SHA256 matches RFC 5869 test case 1 (salt maps to nonce)', () async {
      final okm = await kx.Hkdf(hmac: kx.Hmac.sha256(), outputLength: 42).deriveKey(
        secretKey: kx.SecretKey(_hex('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b')),
        nonce: _hex('000102030405060708090a0b0c'),
        info: _hex('f0f1f2f3f4f5f6f7f8f9'),
      );
      expect(
        await okm.extractBytes(),
        _hex('3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865'),
      );
    });

    test('X25519 matches RFC 7748 section 6.1', () async {
      final algorithm = kx.X25519();
      final alice = await algorithm.newKeyPairFromSeed(
        _hex('77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a'),
      );
      expect(
        await PairingProtocol.publicKeyOf(alice),
        _hex('8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a'),
      );
      final shared = await algorithm.sharedSecretKey(
        keyPair: alice,
        remotePublicKey: kx.SimplePublicKey(
          _hex('de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f'),
          type: kx.KeyPairType.x25519,
        ),
      );
      expect(await shared.extractBytes(), _hex('4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742'));
    });
  });

  group('PairingProtocol', () {
    PairingParty party(String id, List<int> key, {String fingerprintByte = 'ab'}) => PairingParty(
      deviceId: id,
      deviceName: 'Device $id',
      platform: 'windows',
      appVersion: '4.0.0',
      publicKey: key,
      tlsFingerprint: 'sha256:${fingerprintByte * 32}',
    );

    final initiator = party('device-b', List<int>.filled(32, 1));
    final responder = party('device-a', List<int>.filled(32, 2), fingerprintByte: 'cd');
    final transcript = PairingProtocol.transcriptHash(initiator: initiator, responder: responder);
    final nonceI = List<int>.filled(32, 3);
    final nonceR = List<int>.filled(32, 4);

    test('the transcript binds every field and the roles', () {
      expect(transcript, hasLength(32));
      expect(
        PairingProtocol.transcriptHash(initiator: responder, responder: initiator),
        isNot(transcript),
        reason: 'swapping roles must change the transcript',
      );
      final renamed = PairingParty(
        deviceId: initiator.deviceId,
        deviceName: 'Someone else',
        platform: initiator.platform,
        appVersion: initiator.appVersion,
        publicKey: initiator.publicKey,
        tlsFingerprint: initiator.tlsFingerprint,
      );
      expect(PairingProtocol.transcriptHash(initiator: renamed, responder: responder), isNot(transcript));
    });

    test('length prefixes keep adjacent fields unambiguous', () {
      PairingParty named(String id, String name) => PairingParty(
        deviceId: id,
        deviceName: name,
        platform: 'windows',
        appVersion: '4.0.0',
        publicKey: List<int>.filled(32, 1),
        tlsFingerprint: 'sha256:${'ab' * 32}',
      );
      expect(
        PairingProtocol.transcriptHash(initiator: named('ab', 'c'), responder: responder),
        isNot(PairingProtocol.transcriptHash(initiator: named('a', 'bc'), responder: responder)),
      );
    });

    test('the commitment opens only to its nonce and transcript', () {
      final commitment = PairingProtocol.commitment(responderNonce: nonceR, transcriptHash: transcript);
      expect(
        PairingProtocol.commitmentMatches(commitment: commitment, responderNonce: nonceR, transcriptHash: transcript),
        isTrue,
      );
      expect(
        PairingProtocol.commitmentMatches(commitment: commitment, responderNonce: nonceI, transcriptHash: transcript),
        isFalse,
        reason: 'a nonce chosen after the fact must not open the commitment',
      );
      final otherTranscript = PairingProtocol.transcriptHash(initiator: responder, responder: initiator);
      expect(
        PairingProtocol.commitmentMatches(
          commitment: commitment,
          responderNonce: nonceR,
          transcriptHash: otherTranscript,
        ),
        isFalse,
      );
    });

    test('the code is six digits, deterministic, and sensitive to both nonces', () {
      final sas = PairingProtocol.sas(transcriptHash: transcript, initiatorNonce: nonceI, responderNonce: nonceR);
      expect(sas, matches(RegExp(r'^\d{6}$')));
      expect(PairingProtocol.sas(transcriptHash: transcript, initiatorNonce: nonceI, responderNonce: nonceR), sas);
      final changed = List<int>.of(nonceI)..[0] = 9;
      expect(
        PairingProtocol.sas(transcriptHash: transcript, initiatorNonce: changed, responderNonce: nonceR),
        isNot(sas),
      );
    });

    test('codes spread over the whole six-digit space', () {
      final random = Random(7);
      final codes = <String>{
        for (var i = 0; i < 200; i++)
          PairingProtocol.sas(
            transcriptHash: transcript,
            initiatorNonce: PairingProtocol.newNonce(random),
            responderNonce: nonceR,
          ),
      };
      expect(codes.length, greaterThan(195), reason: 'collisions in 200 draws from 10^6 should be rare');
    });

    test('both ends derive the same secret; confirmations are role-bound', () async {
      final initiatorKeys = await PairingProtocol.newKeyPair();
      final responderKeys = await PairingProtocol.newKeyPair();
      final initiatorKey = await PairingProtocol.publicKeyOf(initiatorKeys);
      final responderKey = await PairingProtocol.publicKeyOf(responderKeys);
      final hash = PairingProtocol.transcriptHash(
        initiator: party('device-b', initiatorKey),
        responder: party('device-a', responderKey, fingerprintByte: 'cd'),
      );

      final initiatorSecret = await PairingProtocol.deriveSecret(
        localKeyPair: initiatorKeys,
        remotePublicKey: responderKey,
        transcriptHash: hash,
        initiatorNonce: nonceI,
        responderNonce: nonceR,
      );
      final responderSecret = await PairingProtocol.deriveSecret(
        localKeyPair: responderKeys,
        remotePublicKey: initiatorKey,
        transcriptHash: hash,
        initiatorNonce: nonceI,
        responderNonce: nonceR,
      );
      expect(initiatorSecret, hasLength(32));
      expect(initiatorSecret, responderSecret);

      final initiatorMac = PairingProtocol.confirmationMac(
        secret: initiatorSecret,
        role: PairingRole.initiator,
        transcriptHash: hash,
        initiatorNonce: nonceI,
        responderNonce: nonceR,
      );
      expect(
        PairingProtocol.confirmationMatches(
          mac: initiatorMac,
          secret: responderSecret,
          role: PairingRole.initiator,
          transcriptHash: hash,
          initiatorNonce: nonceI,
          responderNonce: nonceR,
        ),
        isTrue,
      );
      expect(
        PairingProtocol.confirmationMatches(
          mac: initiatorMac,
          secret: responderSecret,
          role: PairingRole.responder,
          transcriptHash: hash,
          initiatorNonce: nonceI,
          responderNonce: nonceR,
        ),
        isFalse,
        reason: 'a confirmation cannot be reflected back as the other role',
      );
    });

    test('a low-order public key is refused', () async {
      final keys = await PairingProtocol.newKeyPair();
      await expectLater(
        PairingProtocol.deriveSecret(
          localKeyPair: keys,
          remotePublicKey: List<int>.filled(32, 0),
          transcriptHash: transcript,
          initiatorNonce: nonceI,
          responderNonce: nonceR,
        ),
        throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'pairing_key_invalid')),
      );
    });

    test('PairingParty validates what arrives from the wire', () {
      expect(PairingParty.fromJson(initiator.toJson()).deviceId, initiator.deviceId);

      final shortKey = initiator.toJson()..['publicKey'] = 'AAAA';
      expect(() => PairingParty.fromJson(shortKey), throwsA(isA<LanSyncError>()));

      final badFingerprint = initiator.toJson()..['tlsFingerprint'] = 'md5:nope';
      expect(() => PairingParty.fromJson(badFingerprint), throwsA(isA<LanSyncError>()));

      final missingName = initiator.toJson()..remove('deviceName');
      expect(() => PairingParty.fromJson(missingName), throwsA(isA<LanSyncError>()));
    });
  });
}

List<int> _hex(String hex) => [
  for (var i = 0; i + 1 < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
];
