import 'dart:convert' show base64Url, jsonEncode, utf8;
import 'dart:io' show ContentType, HttpClient, HttpClientResponse, SecurityContext;
import 'dart:math' show Random;

import 'package:live_lan_sync/src/config/config.dart' show LanSyncDeviceConfig, LanSyncSecurityConfig;
import 'package:live_lan_sync/src/domain/errors/errors.dart' show LanSyncError, LanSyncErrorCategory;
import 'package:live_lan_sync/src/domain/protocol/lan_sync_protocol.dart' show LanSyncProtocol;
import 'package:live_lan_sync/src/logging/logging.dart';
import 'package:live_lan_sync/src/pairing/fingerprint.dart' show KeyFingerprints;
import 'package:live_lan_sync/src/pairing/pairing_outcome.dart'
    show PairingCompleted, PairingFailed, PairingFailureReason, PairingOutcome;
import 'package:live_lan_sync/src/pairing/pairing_protocol.dart' show PairingParty, PairingProtocol, PairingRole;
import 'package:live_lan_sync/src/pairing/pairing_responder.dart' show PairingGrants;
import 'package:live_lan_sync/src/security/secure_credential_store.dart' show SecureCredentialStore, SecureKey;
import 'package:live_lan_sync/src/security/tls_identity.dart' show TlsIdentity;
import 'package:live_lan_sync/src/store/store.dart' show LanSyncStore;
import 'package:live_lan_sync/src/transport/http_json.dart' show HttpJson;

/// The initiator half of the pairing ceremony: this device found another
/// one (mDNS or a typed address) and asks to pair (spec §9.2).
///
/// [begin] runs the exchange up to the short authentication string; the
/// host shows [OutgoingPairing.sas] and, once its user confirmed that both
/// screens show the same code, calls [OutgoingPairing.confirm].
final class PairingInitiator {
  /// An initiator for this device.
  new({
    required this.store,
    required this.credentials,
    required this.deviceConfig,
    required this.tlsIdentity,
    this.security = const LanSyncSecurityConfig(),
    this.pollInterval = const Duration(milliseconds: 500),
    this.requestTimeout = const Duration(seconds: 15),
    LanSyncLogger? logger,
    DateTime Function()? now,
    Random? random,
  }) : _log = logger?.area(LanSyncLogArea.pairing) ?? LanSyncLogger.silent.area(LanSyncLogArea.pairing),
       _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  /// The persistence the new trust record goes to.
  final LanSyncStore store;

  /// The secure storage the pairing secret goes to.
  final SecureCredentialStore credentials;

  /// This device's published facts.
  final LanSyncDeviceConfig deviceConfig;

  /// This device's certificate, whose fingerprint the responder pins.
  final TlsIdentity tlsIdentity;

  /// The session lifetime this device honours.
  final LanSyncSecurityConfig security;

  /// How often the outcome is polled while the other user decides.
  final Duration pollInterval;

  /// The bound on every request of the ceremony.
  final Duration requestTimeout;

  final DateTime Function() _now;
  final Random _random;
  final LanSyncLog _log;

  /// Starts pairing with the device at [host]:[port], whose pairing window
  /// must be open.
  ///
  /// Throws a [LanSyncError]: `identityMismatch` when the certificate the
  /// device presents is not the one it claims, `pairing` when it breaks the
  /// protocol (a commitment that does not open — the mark of a tampered
  /// exchange), or whatever the device refused with (window closed, rate
  /// limited).
  Future<OutgoingPairing> begin({required String host, required int port}) async {
    final channel = _PairingChannel(host, port, requestTimeout);
    try {
      final keyPair = await PairingProtocol.newKeyPair();
      final local = PairingParty(
        deviceId: deviceConfig.deviceId,
        deviceName: deviceConfig.deviceName,
        platform: deviceConfig.platform,
        appVersion: deviceConfig.appVersion,
        publicKey: await PairingProtocol.publicKeyOf(keyPair),
        tlsFingerprint: tlsIdentity.fingerprint,
      );
      final challenge = await channel.post('pair/challenge', <String, Object?>{'initiator': local.toJson()});
      final responder = PairingParty.fromJson(switch (challenge['responder']) {
        final Map<Object?, Object?> object => object.cast<String, Object?>(),
        _ => const <String, Object?>{},
      });
      if (!KeyFingerprints.secureEquals(responder.tlsFingerprint, channel.observedFingerprint!)) {
        throw const LanSyncError(
          category: LanSyncErrorCategory.identityMismatch,
          code: 'pairing_certificate_mismatch',
          message: 'The device presented a different certificate than it claims.',
        );
      }
      channel.expectedFingerprint = responder.tlsFingerprint;
      if (responder.deviceId == deviceConfig.deviceId) {
        throw const LanSyncError(
          category: LanSyncErrorCategory.dataValidation,
          code: 'pairing_with_self',
          message: 'A device cannot pair with itself.',
        );
      }
      final sessionId = switch (challenge['sessionId']) {
        final String id when id.isNotEmpty && id.length <= 64 => id,
        _ => throw const LanSyncError(
          category: LanSyncErrorCategory.dataValidation,
          code: 'pairing_message_invalid',
          message: 'The pairing session id is missing.',
        ),
      };
      final commitment = PairingProtocol.decodeBytes(challenge['commitment'], length: PairingProtocol.keyLength);
      final transcriptHash = PairingProtocol.transcriptHash(initiator: local, responder: responder);
      final initiatorNonce = PairingProtocol.newNonce(_random);

      final reveal = await channel.post('pair/reveal', <String, Object?>{
        'sessionId': sessionId,
        'nonce': base64Url.encode(initiatorNonce),
      });
      final responderNonce = PairingProtocol.decodeBytes(reveal['nonce'], length: PairingProtocol.keyLength);
      if (!PairingProtocol.commitmentMatches(
        commitment: commitment,
        responderNonce: responderNonce,
        transcriptHash: transcriptHash,
      )) {
        _log.error('the other device broke the pairing protocol', fields: {'device': responder.deviceId});
        throw const LanSyncError(
          category: LanSyncErrorCategory.pairing,
          code: 'pairing_commitment_mismatch',
          message: 'The other device broke the pairing protocol; the exchange may have been tampered with.',
        );
      }
      final secret = await PairingProtocol.deriveSecret(
        localKeyPair: keyPair,
        remotePublicKey: responder.publicKey,
        transcriptHash: transcriptHash,
        initiatorNonce: initiatorNonce,
        responderNonce: responderNonce,
      );
      _log.info(
        'pairing started; compare the codes',
        fields: {'device': responder.deviceId, 'fingerprint': LanSyncLog.shortFingerprint(responder.tlsFingerprint)},
      );
      return OutgoingPairing._(
        this,
        channel,
        responder,
        PairingProtocol.sas(
          transcriptHash: transcriptHash,
          initiatorNonce: initiatorNonce,
          responderNonce: responderNonce,
        ),
        _now().add(security.pairingCodeTtl),
        sessionId,
        secret,
        transcriptHash,
        initiatorNonce,
        responderNonce,
      );
    } on Object {
      channel.close();
      rethrow;
    }
  }
}

/// A pairing this device started, waiting for its user to compare codes.
final class OutgoingPairing {
  new _(
    this._initiator,
    this._channel,
    this.responder,
    this.sas,
    this.expiresAt,
    this._sessionId,
    this._secret,
    this._transcriptHash,
    this._initiatorNonce,
    this._responderNonce,
  );

  final PairingInitiator _initiator;
  final _PairingChannel _channel;
  final String _sessionId;
  final List<int> _secret;
  final List<int> _transcriptHash;
  final List<int> _initiatorNonce;
  final List<int> _responderNonce;
  bool _finished = false;

  /// The device being paired; its name belongs in the prompt.
  final PairingParty responder;

  /// The six-digit code this device's user compares with the other screen.
  final String sas;

  /// When this device stops waiting for the other user.
  final DateTime expiresAt;

  /// This device's user saw the same code on both screens: send the key
  /// confirmation and wait for the other user's decision. Grants [grants]
  /// to the responder once both confirmed.
  Future<PairingOutcome> confirm({PairingGrants grants = const PairingGrants()}) async {
    _claim();
    try {
      final mac = PairingProtocol.confirmationMac(
        secret: _secret,
        role: PairingRole.initiator,
        transcriptHash: _transcriptHash,
        initiatorNonce: _initiatorNonce,
        responderNonce: _responderNonce,
      );
      var status = await _channel.post('pair/confirm', <String, Object?>{
        'sessionId': _sessionId,
        'decision': 'accept',
        'mac': base64Url.encode(mac),
      });
      while (status['status'] == 'pending') {
        if (!_initiator._now().isBefore(expiresAt)) {
          return const PairingFailed(PairingFailureReason.sessionExpired, 'The other device did not answer in time.');
        }
        await Future<void>.delayed(_initiator.pollInterval);
        status = await _channel.post('pair/status', <String, Object?>{'sessionId': _sessionId});
      }
      return switch (status['status']) {
        'accepted' => await _complete(status, grants),
        'rejected' => const PairingFailed(
          PairingFailureReason.rejectedByPeer,
          'The other device declined the pairing.',
        ),
        'expired' => const PairingFailed(PairingFailureReason.sessionExpired, 'The pairing request expired.'),
        _ => const PairingFailed(
          PairingFailureReason.keyConfirmationFailed,
          'The other device could not verify this device; the exchange was tampered with.',
        ),
      };
    } finally {
      _release();
    }
  }

  /// This device's user declined, or the codes differed.
  Future<void> reject() async {
    if (_finished) return;
    _claim();
    try {
      await _channel.post('pair/confirm', <String, Object?>{'sessionId': _sessionId, 'decision': 'reject'});
    } on Object {
      // Best effort: the other side's session expires on its own.
    } finally {
      _release();
    }
  }

  Future<PairingOutcome> _complete(Map<String, Object?> status, PairingGrants grants) async {
    final responderMac = PairingProtocol.decodeBytes(status['mac'], length: PairingProtocol.keyLength);
    final verified = PairingProtocol.confirmationMatches(
      mac: responderMac,
      secret: _secret,
      role: PairingRole.responder,
      transcriptHash: _transcriptHash,
      initiatorNonce: _initiatorNonce,
      responderNonce: _responderNonce,
    );
    if (!verified) {
      return const PairingFailed(
        PairingFailureReason.keyConfirmationFailed,
        'The other device derived a different key; the exchange was tampered with.',
      );
    }
    final existing = await _initiator.store.deviceTrust(responder.deviceId);
    if (existing != null &&
        !existing.revoked &&
        !KeyFingerprints.matches(responder.tlsFingerprint, existing.keyFingerprint)) {
      return const PairingFailed(
        PairingFailureReason.identityTaken,
        'This device id is already paired with a different certificate.',
      );
    }
    final trust = grants.trustFor(responder, _initiator._now());
    // The store gets its own copy: this object's copy is wiped on release.
    await _initiator.credentials.write(SecureKey.peerPairing(responder.deviceId), List<int>.of(_secret));
    await _initiator.store.putDeviceTrust(trust);
    _initiator._log.info('paired', fields: {'device': responder.deviceId});
    return PairingCompleted(trust);
  }

  void _claim() {
    if (_finished) {
      throw StateError('This pairing has already finished.');
    }
    _finished = true;
  }

  void _release() {
    _secret.fillRange(0, _secret.length, 0);
    _channel.close();
  }
}

/// The TLS channel of one ceremony. No pin exists yet, so every certificate
/// is admitted at the handshake and then checked per response: the first
/// one seen must equal the fingerprint the responder claims, and every
/// later response must present the same certificate. Pairing messages
/// carry nothing secret, and the code comparison authenticates them all.
final class _PairingChannel {
  new(this.host, this.port, this.timeout) : _client = HttpClient(context: SecurityContext()) {
    _client
      ..connectionTimeout = timeout
      ..badCertificateCallback = (_, _, _) => true;
  }

  static const int _maxResponseBytes = 64 * 1024;

  final String host;
  final int port;
  final Duration timeout;
  final HttpClient _client;
  String? observedFingerprint;
  String? expectedFingerprint;

  Future<Map<String, Object?>> post(String path, Map<String, Object?> body) async {
    final request = await _client.postUrl(Uri.parse('https://$host:$port${LanSyncProtocol.apiPrefix}$path'));
    final bytes = utf8.encode(jsonEncode(body));
    request
      ..headers.contentType = ContentType.json
      ..contentLength = bytes.length
      ..add(bytes);
    final response = await request.close().timeout(timeout);
    final certificate = response.certificate;
    final observed = certificate == null ? null : KeyFingerprints.sha256(certificate.der);
    final expected = expectedFingerprint ?? observedFingerprint ?? observed;
    if (observed == null || !KeyFingerprints.secureEquals(observed, expected!)) {
      await response.drain<void>();
      throw const LanSyncError(
        category: LanSyncErrorCategory.identityMismatch,
        code: 'pairing_certificate_changed',
        message: 'The device changed its certificate during pairing.',
      );
    }
    observedFingerprint ??= observed;
    final responseBody = await _read(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpJson.errorFromResponse(response.statusCode, responseBody);
    }
    return HttpJson.decodeObject(responseBody);
  }

  void close() => _client.close(force: true);

  static Future<List<int>> _read(HttpClientResponse response) async {
    final body = <int>[];
    await for (final chunk in response) {
      if (body.length + chunk.length > _maxResponseBytes) {
        throw const LanSyncError(
          category: LanSyncErrorCategory.dataValidation,
          code: 'response_too_large',
          message: 'The device answered with an oversized response.',
        );
      }
      body.addAll(chunk);
    }
    return body;
  }
}
