import 'dart:convert' show base64Url, utf8;
import 'dart:math' show Random;
import 'dart:typed_data' show BytesBuilder, Uint8List;

import 'package:crypto/crypto.dart' as crypto show Hmac, sha256;
import 'package:cryptography/cryptography.dart' as kx;

import 'package:live_lan_sync/src/domain/errors/errors.dart' show LanSyncError, LanSyncErrorCategory;
import 'package:live_lan_sync/src/pairing/fingerprint.dart' show KeyFingerprints;

/// The public facts one end contributes to a pairing transcript.
///
/// Everything here is public — ids, names, the ephemeral X25519 public key
/// and the long-term TLS certificate fingerprint — and everything here is
/// authenticated: the short authentication string both users compare is
/// computed over all of it.
final class PairingParty {
  /// One end's pairing facts.
  const new({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    required this.publicKey,
    required this.tlsFingerprint,
  });

  /// Restores a party from its wire form.
  ///
  /// Throws a [LanSyncError] with `dataValidation` for missing, oversized or
  /// malformed fields, a public key that is not 32 bytes, or a fingerprint
  /// that is not a SHA-256.
  factory fromJson(Map<String, Object?> json) {
    String text(String key, int maxLength) => switch (json[key]) {
      final String value when value.isNotEmpty && value.length <= maxLength => value,
      _ => throw _invalid('The pairing field "$key" is missing or malformed.'),
    };
    final publicKey = PairingProtocol.decodeBytes(json['publicKey'], length: PairingProtocol.keyLength);
    final fingerprint = KeyFingerprints.normalize(text('tlsFingerprint', 80));
    if (fingerprint == null) {
      throw _invalid('The pairing fingerprint is not a SHA-256 fingerprint.');
    }
    return PairingParty(
      deviceId: text('deviceId', 128),
      deviceName: text('deviceName', 128),
      platform: text('platform', 64),
      appVersion: text('appVersion', 64),
      publicKey: publicKey,
      tlsFingerprint: fingerprint,
    );
  }

  /// The stable device id.
  final String deviceId;

  /// The user-visible name, shown in the other user's prompt.
  final String deviceName;

  /// The platform label.
  final String platform;

  /// The application version.
  final String appVersion;

  /// The ephemeral X25519 public key for this pairing only.
  final List<int> publicKey;

  /// The `sha256:<hex>` fingerprint of this end's TLS certificate, which the
  /// other end pins once pairing completes.
  final String tlsFingerprint;

  /// The wire form.
  Map<String, Object?> toJson() => <String, Object?>{
    'deviceId': deviceId,
    'deviceName': deviceName,
    'platform': platform,
    'appVersion': appVersion,
    'publicKey': base64Url.encode(publicKey),
    'tlsFingerprint': tlsFingerprint,
  };
}

/// Which end of the ceremony a computation is for.
enum PairingRole {
  /// The device that discovered the other and started pairing.
  initiator,

  /// The device whose user opened its pairing window.
  responder,
}

/// The pairing ceremony's primitives (spec §9.2, §9.3).
///
/// The construction follows Bluetooth Secure Simple Pairing's numeric
/// comparison, with SHA-256/HMAC-SHA256 in place of AES-CMAC:
///
/// 1. Both ends exchange [PairingParty] facts, each with a fresh X25519
///    public key. The responder answers with a [commitment] to its nonce
///    over the transcript before it has seen the initiator's nonce.
/// 2. The initiator sends its nonce; the responder reveals its own, and the
///    initiator checks the commitment. A man in the middle had to fix its
///    keys and nonce on each leg before learning the honest nonce on that
///    leg, so the two legs' codes agree only by chance (10⁻⁶ per attempt,
///    then rate-limited).
/// 3. Both ends show the six-digit [sas]; both users compare and confirm.
/// 4. The pairing secret is HKDF-SHA256 over the X25519 shared secret,
///    salted with the transcript and both nonces; it never travels. Each
///    end proves it holds the same secret with a [confirmationMac].
///
/// Only reviewed primitives are used (X25519, HKDF, HMAC-SHA256, SHA-256);
/// the message order is the published protocol's, not an invention.
abstract final class PairingProtocol {
  /// The length of X25519 public keys and of both nonces, in bytes.
  static const keyLength = 32;

  /// How many digits the short authentication string has.
  static const sasDigits = 6;

  static const _label = 'live_lan_sync/v1/pairing';

  /// A fresh X25519 key pair for one ceremony.
  static Future<kx.SimpleKeyPair> newKeyPair() => kx.X25519().newKeyPair();

  /// The raw bytes of [keyPair]'s public key.
  static Future<List<int>> publicKeyOf(kx.SimpleKeyPair keyPair) async => (await keyPair.extractPublicKey()).bytes;

  /// A fresh 32-byte nonce.
  static List<int> newNonce([Random? random]) {
    final generator = random ?? Random.secure();
    return List<int>.generate(keyLength, (_) => generator.nextInt(256));
  }

  /// SHA-256 over an unambiguous, length-prefixed encoding of both parties,
  /// initiator first. Every later value is bound to this hash.
  static List<int> transcriptHash({required PairingParty initiator, required PairingParty responder}) {
    final builder = BytesBuilder(copy: false);
    void field(List<int> bytes) {
      final length = bytes.length;
      builder
        ..add([(length >> 24) & 0xFF, (length >> 16) & 0xFF, (length >> 8) & 0xFF, length & 0xFF])
        ..add(bytes);
    }

    void text(String value) => field(utf8.encode(value));

    text(_label);
    for (final party in [initiator, responder]) {
      text(party.deviceId);
      text(party.deviceName);
      text(party.platform);
      text(party.appVersion);
      field(party.publicKey);
      text(party.tlsFingerprint);
    }
    return crypto.sha256.convert(builder.takeBytes()).bytes;
  }

  /// The responder's commitment: HMAC-SHA256 keyed with its nonce over the
  /// transcript hash. Binding (the nonce cannot change after the fact) and
  /// hiding (the commitment reveals nothing usable about the nonce).
  static List<int> commitment({required List<int> responderNonce, required List<int> transcriptHash}) =>
      crypto.Hmac(crypto.sha256, responderNonce).convert(transcriptHash).bytes;

  /// Whether [commitment] opens to [responderNonce] over [transcriptHash].
  static bool commitmentMatches({
    required List<int> commitment,
    required List<int> responderNonce,
    required List<int> transcriptHash,
  }) => bytesEqual(
    commitment,
    PairingProtocol.commitment(responderNonce: responderNonce, transcriptHash: transcriptHash),
  );

  /// The six-digit short authentication string both users compare.
  static String sas({
    required List<int> transcriptHash,
    required List<int> initiatorNonce,
    required List<int> responderNonce,
  }) {
    final digest = crypto.sha256.convert(<int>[
      ...utf8.encode('$_label/sas'),
      ...transcriptHash,
      ...initiatorNonce,
      ...responderNonce,
    ]).bytes;
    final value = ((digest[0] << 24) | (digest[1] << 16) | (digest[2] << 8) | digest[3]) % 1000000;
    return value.toString().padLeft(sasDigits, '0');
  }

  /// Derives the 32-byte pairing secret both ends store under the other's
  /// device id.
  ///
  /// Throws a [LanSyncError] with `pairing` when the peer's key yields an
  /// all-zero shared secret (a low-order point; RFC 7748 §6.1).
  static Future<List<int>> deriveSecret({
    required kx.SimpleKeyPair localKeyPair,
    required List<int> remotePublicKey,
    required List<int> transcriptHash,
    required List<int> initiatorNonce,
    required List<int> responderNonce,
  }) async {
    const invalidKey = LanSyncError(
      category: LanSyncErrorCategory.pairing,
      code: 'pairing_key_invalid',
      message: 'The other device offered an invalid key.',
    );
    final List<int> sharedBytes;
    try {
      final shared = await kx.X25519().sharedSecretKey(
        keyPair: localKeyPair,
        remotePublicKey: kx.SimplePublicKey(remotePublicKey, type: kx.KeyPairType.x25519),
      );
      sharedBytes = await shared.extractBytes();
    } on Object {
      throw invalidKey;
    }
    if (sharedBytes.every((byte) => byte == 0)) {
      throw invalidKey;
    }
    final salt = crypto.sha256.convert(<int>[
      ...utf8.encode('$_label/salt'),
      ...transcriptHash,
      ...initiatorNonce,
      ...responderNonce,
    ]).bytes;
    final derived = await kx.Hkdf(
      hmac: kx.Hmac.sha256(),
      outputLength: keyLength,
    ).deriveKey(secretKey: kx.SecretKey(sharedBytes), nonce: salt, info: utf8.encode('$_label/secret'));
    // A mutable copy, so callers can wipe it once it is stored.
    return Uint8List.fromList(await derived.extractBytes());
  }

  /// The key-confirmation MAC [role] sends: proof that it derived the same
  /// secret over the same transcript and nonces.
  static List<int> confirmationMac({
    required List<int> secret,
    required PairingRole role,
    required List<int> transcriptHash,
    required List<int> initiatorNonce,
    required List<int> responderNonce,
  }) => crypto.Hmac(crypto.sha256, secret).convert(<int>[
    ...utf8.encode('$_label/confirm/${role.name}'),
    ...transcriptHash,
    ...initiatorNonce,
    ...responderNonce,
  ]).bytes;

  /// Whether [mac] is [role]'s confirmation over the given values.
  static bool confirmationMatches({
    required List<int> mac,
    required List<int> secret,
    required PairingRole role,
    required List<int> transcriptHash,
    required List<int> initiatorNonce,
    required List<int> responderNonce,
  }) => bytesEqual(
    mac,
    confirmationMac(
      secret: secret,
      role: role,
      transcriptHash: transcriptHash,
      initiatorNonce: initiatorNonce,
      responderNonce: responderNonce,
    ),
  );

  /// Decodes a base64url field of exactly [length] bytes.
  ///
  /// Throws a [LanSyncError] with `dataValidation` otherwise.
  static List<int> decodeBytes(Object? value, {required int length}) {
    if (value is! String || value.length > 4 * length) {
      throw _invalid('A pairing value is missing or malformed.');
    }
    final List<int> bytes;
    try {
      bytes = base64Url.decode(base64Url.normalize(value));
    } on FormatException {
      throw _invalid('A pairing value is not valid base64.');
    }
    if (bytes.length != length) {
      throw _invalid('A pairing value has the wrong length.');
    }
    return bytes;
  }

  /// Compares two byte lists in time independent of where they differ.
  static bool bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

LanSyncError _invalid(String message) =>
    LanSyncError(category: LanSyncErrorCategory.dataValidation, code: 'pairing_message_invalid', message: message);
