import 'dart:async' show Completer, StreamController, unawaited;
import 'dart:convert' show base64Url;
import 'dart:math' show Random;

import 'package:cryptography/cryptography.dart' as kx show SimpleKeyPair;
import 'package:live_lan_sync/src/config/config.dart' show LanSyncDeviceConfig, LanSyncSecurityConfig;
import 'package:live_lan_sync/src/domain/device/device.dart' show DeviceFilePermission, DeviceTrust;
import 'package:live_lan_sync/src/domain/errors/errors.dart' show LanSyncError, LanSyncErrorCategory;
import 'package:live_lan_sync/src/logging/logging.dart';
import 'package:live_lan_sync/src/pairing/fingerprint.dart' show KeyFingerprints;
import 'package:live_lan_sync/src/pairing/pairing_outcome.dart'
    show PairingCompleted, PairingFailed, PairingFailureReason, PairingOutcome;
import 'package:live_lan_sync/src/pairing/pairing_protocol.dart' show PairingParty, PairingProtocol, PairingRole;
import 'package:live_lan_sync/src/pairing/pairing_rate_limiter.dart' show PairingRateLimiter;
import 'package:live_lan_sync/src/security/secure_credential_store.dart' show SecureCredentialStore, SecureKey;
import 'package:live_lan_sync/src/security/tls_identity.dart' show TlsIdentity;
import 'package:live_lan_sync/src/store/store.dart' show LanSyncStore;

/// A pairing request waiting for this device's user to compare codes.
final class IncomingPairing {
  /// A request from [initiator] showing [sas].
  const new({required this.sessionId, required this.initiator, required this.sas, required this.expiresAt});

  /// The session to accept or reject.
  final String sessionId;

  /// The device asking to pair; its name and platform belong in the prompt.
  final PairingParty initiator;

  /// The six-digit code this device's user compares with the other screen.
  final String sas;

  /// When the request lapses.
  final DateTime expiresAt;
}

/// The grants this device gives a peer when its user accepts pairing.
///
/// Pairing grants nothing by default (spec §9.4): every scope and file
/// direction is the user's explicit choice.
final class PairingGrants {
  /// The grants for one pairing.
  const new({
    this.readScopes = const <String>{},
    this.writeScopes = const <String>{},
    this.filePermissions = const <DeviceFilePermission>{},
  });

  /// The scopes the peer may read from this device.
  final Set<String> readScopes;

  /// The scopes the peer may write into this device.
  final Set<String> writeScopes;

  /// The file directions this device allows with the peer.
  final Set<DeviceFilePermission> filePermissions;

  /// The trust record these grants produce for [peer].
  DeviceTrust trustFor(PairingParty peer, DateTime pairedAt) => DeviceTrust(
    deviceId: peer.deviceId,
    keyFingerprint: peer.tlsFingerprint,
    displayName: peer.deviceName,
    pairedAt: pairedAt,
    readScopes: readScopes,
    writeScopes: writeScopes,
    filePermissions: filePermissions,
  );
}

enum _SessionState { awaitingReveal, awaitingDecision, completed, rejected, expired, failed }

final class _ResponderSession {
  new({
    required this.sessionId,
    required this.initiator,
    required this.responder,
    required this.keyPair,
    required this.transcriptHash,
    required this.responderNonce,
    required this.remoteAddress,
    required this.expiresAt,
  });

  final String sessionId;
  final PairingParty initiator;
  final PairingParty responder;
  final kx.SimpleKeyPair keyPair;
  final List<int> transcriptHash;
  final List<int> responderNonce;
  final String remoteAddress;
  final DateTime expiresAt;
  final Completer<PairingOutcome> outcome = Completer<PairingOutcome>();

  _SessionState state = _SessionState.awaitingReveal;
  List<int>? initiatorNonce;
  List<int>? secret;
  String? sas;
  PairingGrants? grants;
  bool initiatorConfirmed = false;
  bool completing = false;
  List<int>? responderMac;
}

/// The responder half of the pairing ceremony: the device whose user opened
/// a pairing window and answers a nearby device's request (spec §9.2).
///
/// The server routes `/pair/challenge`, `/pair/reveal`, `/pair/confirm` and
/// `/pair/status` to the `handle*` methods; the host UI listens to
/// [requests] and calls [accept] or [reject] after its user compared the
/// code. Trust and the pairing secret are written only when both users
/// confirmed and the initiator's key confirmation verified.
///
/// Requests are refused unless the window is open, rate-limited per remote
/// address and per claimed device id, and bounded by
/// [LanSyncSecurityConfig.maxPendingPairingSessions].
final class PairingResponder {
  /// A responder for this device.
  new({
    required this.store,
    required this.credentials,
    required this.security,
    required this.deviceConfig,
    required this.tlsIdentity,
    LanSyncLogger? logger,
    DateTime Function()? now,
    Random? random,
  }) : _log = logger?.area(LanSyncLogArea.pairing) ?? LanSyncLogger.silent.area(LanSyncLogArea.pairing),
       _now = now ?? DateTime.now,
       _random = random ?? Random.secure(),
       _deviceLimiter = PairingRateLimiter(
         maxAttempts: security.maxPairingAttempts,
         window: security.rateLimitWindow,
         now: now,
       ),
       _addressLimiter = PairingRateLimiter(
         maxAttempts: security.maxPairingAttempts,
         window: security.rateLimitWindow,
         now: now,
       );

  /// The persistence the new trust record goes to.
  final LanSyncStore store;

  /// The secure storage the pairing secret goes to.
  final SecureCredentialStore credentials;

  /// The ceremony's limits: session lifetime, attempts, concurrency.
  final LanSyncSecurityConfig security;

  /// This device's published facts.
  final LanSyncDeviceConfig deviceConfig;

  /// This device's certificate, whose fingerprint the initiator pins.
  final TlsIdentity tlsIdentity;

  final LanSyncLog _log;

  final DateTime Function() _now;
  final Random _random;
  final PairingRateLimiter _deviceLimiter;
  final PairingRateLimiter _addressLimiter;
  final Map<String, _ResponderSession> _sessions = <String, _ResponderSession>{};
  final StreamController<IncomingPairing> _requests = StreamController<IncomingPairing>.broadcast();
  DateTime? _windowClosesAt;

  /// Requests ready for the user's decision, each emitted once its code is
  /// known.
  Stream<IncomingPairing> get requests => _requests.stream;

  /// Whether new pairing requests are accepted right now.
  bool get isPairingWindowOpen {
    final closesAt = _windowClosesAt;
    return closesAt != null && _now().isBefore(closesAt);
  }

  /// Opens the pairing window, by default for the session lifetime. Nearby
  /// devices can only start pairing while it is open.
  void openPairingWindow({Duration? duration}) {
    final open = duration ?? security.pairingCodeTtl;
    _windowClosesAt = _now().add(open);
    _log.info('pairing window opened', fields: {'seconds': open.inSeconds});
  }

  /// Closes the window. Sessions already started run to their end.
  void closePairingWindow() {
    _windowClosesAt = null;
    _log.info('pairing window closed');
  }

  /// `POST /pair/challenge`: registers the initiator's facts and answers
  /// with this device's facts and the commitment to its nonce.
  Future<Map<String, Object?>> handleChallenge(Map<String, Object?> body, {required String remoteAddress}) async {
    _sweep();
    if (!isPairingWindowOpen) {
      throw const LanSyncError(
        category: LanSyncErrorCategory.permissionDenied,
        code: 'pairing_window_closed',
        message: 'The device is not accepting pairing requests right now.',
      );
    }
    if (!_addressLimiter.allows(remoteAddress)) {
      throw _rateLimited();
    }
    final initiator = PairingParty.fromJson(_object(body['initiator']));
    if (initiator.deviceId == deviceConfig.deviceId) {
      throw const LanSyncError(
        category: LanSyncErrorCategory.dataValidation,
        code: 'pairing_with_self',
        message: 'A device cannot pair with itself.',
      );
    }
    if (!_deviceLimiter.allows(initiator.deviceId)) {
      throw _rateLimited();
    }
    final pending = _sessions.values.where((s) => s.state.index <= _SessionState.awaitingDecision.index).length;
    if (pending >= security.maxPendingPairingSessions) {
      throw const LanSyncError(
        category: LanSyncErrorCategory.rateLimited,
        code: 'pairing_sessions_exhausted',
        message: 'Too many pairing requests are in progress; try again shortly.',
        retryable: true,
      );
    }

    final keyPair = await PairingProtocol.newKeyPair();
    final responder = PairingParty(
      deviceId: deviceConfig.deviceId,
      deviceName: deviceConfig.deviceName,
      platform: deviceConfig.platform,
      appVersion: deviceConfig.appVersion,
      publicKey: await PairingProtocol.publicKeyOf(keyPair),
      tlsFingerprint: tlsIdentity.fingerprint,
    );
    final transcriptHash = PairingProtocol.transcriptHash(initiator: initiator, responder: responder);
    final nonce = PairingProtocol.newNonce(_random);
    final session = _ResponderSession(
      sessionId: base64Url.encode(PairingProtocol.newNonce(_random).sublist(0, 18)),
      initiator: initiator,
      responder: responder,
      keyPair: keyPair,
      transcriptHash: transcriptHash,
      responderNonce: nonce,
      remoteAddress: remoteAddress,
      expiresAt: _now().add(security.pairingCodeTtl),
    );
    _sessions[session.sessionId] = session;
    _log.info(
      'pairing requested',
      fields: {
        'device': initiator.deviceId,
        'name': initiator.deviceName,
        'fingerprint': LanSyncLog.shortFingerprint(initiator.tlsFingerprint),
      },
    );
    return <String, Object?>{
      'sessionId': session.sessionId,
      'responder': responder.toJson(),
      'commitment': base64Url.encode(PairingProtocol.commitment(responderNonce: nonce, transcriptHash: transcriptHash)),
      'expiresAt': session.expiresAt.toUtc().toIso8601String(),
    };
  }

  /// `POST /pair/reveal`: takes the initiator's nonce, reveals this
  /// device's nonce, derives the secret and asks the user to compare.
  Future<Map<String, Object?>> handleReveal(Map<String, Object?> body) async {
    final session = _liveSession(body);
    if (session.state != _SessionState.awaitingReveal) {
      throw _outOfOrder();
    }
    final initiatorNonce = PairingProtocol.decodeBytes(body['nonce'], length: PairingProtocol.keyLength);
    final secret = await PairingProtocol.deriveSecret(
      localKeyPair: session.keyPair,
      remotePublicKey: session.initiator.publicKey,
      transcriptHash: session.transcriptHash,
      initiatorNonce: initiatorNonce,
      responderNonce: session.responderNonce,
    );
    final sas = PairingProtocol.sas(
      transcriptHash: session.transcriptHash,
      initiatorNonce: initiatorNonce,
      responderNonce: session.responderNonce,
    );
    session
      ..initiatorNonce = initiatorNonce
      ..secret = secret
      ..sas = sas
      ..state = _SessionState.awaitingDecision;
    if (!_requests.isClosed) {
      _requests.add(
        IncomingPairing(
          sessionId: session.sessionId,
          initiator: session.initiator,
          sas: sas,
          expiresAt: session.expiresAt,
        ),
      );
    }
    return <String, Object?>{'nonce': base64Url.encode(session.responderNonce)};
  }

  /// `POST /pair/confirm`: the initiator's user decided. An acceptance must
  /// carry the initiator's key confirmation.
  Future<Map<String, Object?>> handleConfirm(Map<String, Object?> body) async {
    _sweep();
    final session = _session(body);
    if (session.state != _SessionState.awaitingDecision) {
      if (session.state == _SessionState.awaitingReveal) throw _outOfOrder();
      return _statusOf(session);
    }
    if (body['decision'] == 'reject') {
      _finish(
        session,
        _SessionState.rejected,
        const PairingFailed(PairingFailureReason.rejectedByPeer, 'The other device declined the pairing.'),
      );
      return _statusOf(session);
    }
    final mac = PairingProtocol.decodeBytes(body['mac'], length: PairingProtocol.keyLength);
    final verified = PairingProtocol.confirmationMatches(
      mac: mac,
      secret: session.secret!,
      role: PairingRole.initiator,
      transcriptHash: session.transcriptHash,
      initiatorNonce: session.initiatorNonce!,
      responderNonce: session.responderNonce,
    );
    if (!verified) {
      _log.warning('key confirmation failed; possible tampering', fields: {'device': session.initiator.deviceId});
      _deviceLimiter.recordFailure(session.initiator.deviceId);
      _addressLimiter.recordFailure(session.remoteAddress);
      _finish(
        session,
        _SessionState.failed,
        const PairingFailed(
          PairingFailureReason.keyConfirmationFailed,
          'The other device derived a different key; the exchange was tampered with.',
        ),
      );
      return _statusOf(session);
    }
    session.initiatorConfirmed = true;
    _log.debug('the other device confirmed', fields: {'device': session.initiator.deviceId});
    await _maybeComplete(session);
    return _statusOf(session);
  }

  /// `POST /pair/status`: where the session stands; an accepted session
  /// carries this device's key confirmation.
  Map<String, Object?> handleStatus(Map<String, Object?> body) {
    _sweep();
    return _statusOf(_session(body));
  }

  /// This device's user compared the codes and they match: grant [grants]
  /// to the initiator. Completes when the initiator has confirmed too.
  Future<PairingOutcome> accept(String sessionId, {PairingGrants grants = const PairingGrants()}) {
    _sweep();
    final session = _sessions[sessionId];
    if (session == null) {
      return Future.value(
        const PairingFailed(PairingFailureReason.unknownSession, 'The pairing request is no longer available.'),
      );
    }
    if (session.state == _SessionState.awaitingDecision && session.grants == null) {
      session.grants = grants;
      unawaited(_maybeComplete(session));
    }
    return session.outcome.future;
  }

  /// This device's user declined, or the codes differed.
  void reject(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null || session.state.index > _SessionState.awaitingDecision.index) return;
    _finish(
      session,
      _SessionState.rejected,
      const PairingFailed(PairingFailureReason.rejectedByUser, 'The pairing was declined on this device.'),
    );
  }

  /// Fails every open session and closes the request stream.
  Future<void> dispose() async {
    for (final session in _sessions.values.toList()) {
      if (session.state.index <= _SessionState.awaitingDecision.index) {
        _finish(
          session,
          _SessionState.expired,
          const PairingFailed(PairingFailureReason.sessionExpired, 'Pairing stopped on this device.'),
        );
      }
    }
    _sessions.clear();
    await _requests.close();
  }

  Future<void> _maybeComplete(_ResponderSession session) async {
    final grants = session.grants;
    if (grants == null ||
        !session.initiatorConfirmed ||
        session.completing ||
        session.state != _SessionState.awaitingDecision) {
      return;
    }
    session.completing = true;
    try {
      final existing = await store.deviceTrust(session.initiator.deviceId);
      if (existing != null &&
          !existing.revoked &&
          !KeyFingerprints.matches(session.initiator.tlsFingerprint, existing.keyFingerprint)) {
        _finish(
          session,
          _SessionState.failed,
          const PairingFailed(
            PairingFailureReason.identityTaken,
            'This device id is already paired with a different certificate.',
          ),
        );
        return;
      }
      final secret = session.secret!;
      session.responderMac = PairingProtocol.confirmationMac(
        secret: secret,
        role: PairingRole.responder,
        transcriptHash: session.transcriptHash,
        initiatorNonce: session.initiatorNonce!,
        responderNonce: session.responderNonce,
      );
      final trust = grants.trustFor(session.initiator, _now());
      // The store gets its own copy: the session's copy is wiped below.
      await credentials.write(SecureKey.peerPairing(session.initiator.deviceId), List<int>.of(secret));
      await store.putDeviceTrust(trust);
      _deviceLimiter.reset(session.initiator.deviceId);
      _log.info(
        'paired',
        fields: {
          'device': session.initiator.deviceId,
          'readScopes': trust.readScopes.length,
          'writeScopes': trust.writeScopes.length,
          'files': trust.filePermissions.map((p) => p.name).toList(),
        },
      );
      _finish(session, _SessionState.completed, PairingCompleted(trust));
    } on Object catch (error) {
      session.state = _SessionState.failed;
      _wipe(session);
      if (!session.outcome.isCompleted) {
        session.outcome.completeError(
          LanSyncError(
            category: LanSyncErrorCategory.storage,
            code: 'pairing_persist_failed',
            message: 'The pairing could not be saved on this device.',
            deviceId: session.initiator.deviceId,
            debugContext: error.toString(),
          ),
        );
      }
    }
  }

  Map<String, Object?> _statusOf(_ResponderSession session) => <String, Object?>{
    'status': switch (session.state) {
      _SessionState.awaitingReveal || _SessionState.awaitingDecision => 'pending',
      _SessionState.completed => 'accepted',
      _SessionState.rejected => 'rejected',
      _SessionState.expired => 'expired',
      _SessionState.failed => 'failed',
    },
    if (session.state == _SessionState.completed) 'mac': base64Url.encode(session.responderMac!),
  };

  void _finish(_ResponderSession session, _SessionState state, PairingOutcome outcome) {
    session.state = state;
    _wipe(session);
    if (!session.outcome.isCompleted) {
      session.outcome.complete(outcome);
    }
  }

  /// Zeroes the session's copy of the secret once it is no longer needed.
  static void _wipe(_ResponderSession session) {
    final secret = session.secret;
    if (secret != null) {
      secret.fillRange(0, secret.length, 0);
      session.secret = null;
    }
  }

  /// Expires lapsed sessions and forgets finished ones a lifetime later, so
  /// late status polls still get an answer but memory stays bounded.
  void _sweep() {
    final now = _now();
    for (final session in _sessions.values.toList()) {
      final open = session.state.index <= _SessionState.awaitingDecision.index;
      if (open && !now.isBefore(session.expiresAt)) {
        _finish(
          session,
          _SessionState.expired,
          const PairingFailed(PairingFailureReason.sessionExpired, 'The pairing request expired.'),
        );
      }
      if (!open && now.isAfter(session.expiresAt.add(security.pairingCodeTtl))) {
        _sessions.remove(session.sessionId);
      }
    }
  }

  _ResponderSession _session(Map<String, Object?> body) {
    final session = switch (body['sessionId']) {
      final String id => _sessions[id],
      _ => null,
    };
    if (session == null) {
      throw const LanSyncError(
        category: LanSyncErrorCategory.pairing,
        code: 'pairing_session_unknown',
        message: 'The pairing session is unknown or has ended.',
      );
    }
    return session;
  }

  _ResponderSession _liveSession(Map<String, Object?> body) {
    _sweep();
    final session = _session(body);
    if (session.state == _SessionState.expired) {
      throw const LanSyncError(
        category: LanSyncErrorCategory.pairing,
        code: 'pairing_session_expired',
        message: 'The pairing request expired.',
      );
    }
    return session;
  }

  static Map<String, Object?> _object(Object? value) => switch (value) {
    final Map<Object?, Object?> object => object.cast<String, Object?>(),
    _ => throw const LanSyncError(
      category: LanSyncErrorCategory.dataValidation,
      code: 'pairing_message_invalid',
      message: 'The pairing message is malformed.',
    ),
  };

  static LanSyncError _rateLimited() => const LanSyncError(
    category: LanSyncErrorCategory.rateLimited,
    code: 'pairing_rate_limited',
    message: 'Too many pairing attempts; wait and retry.',
  );

  static LanSyncError _outOfOrder() => const LanSyncError(
    category: LanSyncErrorCategory.pairing,
    code: 'pairing_step_out_of_order',
    message: 'The pairing step arrived out of order.',
  );
}
