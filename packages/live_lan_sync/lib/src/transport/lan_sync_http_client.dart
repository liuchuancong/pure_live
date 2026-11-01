import 'dart:async' show StreamController, StreamSubscription, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:io' show ContentType, HttpClient, HttpClientResponse, SecurityContext, WebSocket, X509Certificate;

import 'package:live_lan_sync/src/config/config.dart' show LanSyncDeviceConfig;
import 'package:live_lan_sync/src/domain/errors/errors.dart' show LanSyncError, LanSyncErrorCategory;
import 'package:live_lan_sync/src/domain/protocol/lan_sync_protocol.dart' show LanSyncProtocol;
import 'package:live_lan_sync/src/logging/logging.dart' show LanSyncLog, LanSyncLogArea, LanSyncLogger;
import 'package:live_lan_sync/src/pairing/fingerprint.dart' show KeyFingerprints;
import 'package:live_lan_sync/src/security/secure_credential_store.dart' show SecureCredentialStore, SecureKey;
import 'package:live_lan_sync/src/transport/http_auth.dart' show LanSyncHttpAuth;
import 'package:live_lan_sync/src/transport/http_json.dart' show HttpJson;
import 'package:live_lan_sync/src/transport/request_signer.dart' show RequestSigner;

/// The answer to a completed protocol negotiation.
final class HelloResult {
  /// A successful negotiation.
  const new({required this.protocolVersion, required this.device});

  /// The version the peer answered with.
  final int protocolVersion;

  /// The peer's published device facts.
  final Map<String, Object?> device;
}

/// The protocol client: signed requests to one paired peer over pinned TLS
/// (spec §14).
///
/// The TLS layer accepts exactly one certificate — the one whose SHA-256
/// matches [pin], learned during pairing. The client trusts no certificate
/// authority at all, so every certificate goes through the pin check before
/// a byte of the request is sent. Every request then carries this device's
/// id, a fresh nonce, the timestamp and an HMAC over the canonical string,
/// keyed with the pairing secret held in [credentials] under the peer's id.
final class LanSyncHttpClient {
  /// A client for the paired peer at [host]:[port].
  ///
  /// Throws a [LanSyncError] with `configuration` when
  /// [pinnedPeerFingerprint] is not a SHA-256 fingerprint.
  new({
    required this.localDeviceId,
    required this.peerDeviceId,
    required this.host,
    required this.port,
    required this.credentials,
    required String pinnedPeerFingerprint,
    this.requestTimeout = const Duration(seconds: 30),
    this.maxResponseBytes = 16 * 1024 * 1024,
    LanSyncLogger? logger,
    DateTime Function()? now,
  }) : _log = logger?.area(LanSyncLogArea.transport) ?? LanSyncLogger.silent.area(LanSyncLogArea.transport),
       pin = KeyFingerprints.normalize(pinnedPeerFingerprint) ?? (throw _invalidPin),
       // No trusted roots (the default): every certificate meets the pin.
       _inner = HttpClient(context: SecurityContext()),
       _now = now ?? DateTime.now {
    _inner
      ..connectionTimeout = const Duration(seconds: 15)
      ..badCertificateCallback = (certificate, _, _) {
        final pinned = _pinned(certificate);
        if (!pinned) {
          _rejectedFingerprint = KeyFingerprints.sha256(certificate.der);
        }
        return pinned;
      };
  }

  /// This device's id, sent as the authenticated sender.
  final String localDeviceId;

  /// The paired peer this client talks to; names the pairing secret.
  final String peerDeviceId;

  /// The peer's host address, discovered or manually entered.
  final String host;

  /// The peer's listening port.
  final int port;

  /// The secure storage holding this end's copy of the pairing secret.
  final SecureCredentialStore credentials;

  /// The normalized certificate fingerprint the peer must present.
  final String pin;

  /// The bound on one request, response included.
  final Duration requestTimeout;

  /// The largest response body accepted.
  final int maxResponseBytes;

  final HttpClient _inner;
  final LanSyncLog _log;
  final DateTime Function() _now;
  String? _rejectedFingerprint;
  StreamController<Map<String, Object?>>? _eventController;
  StreamSubscription<dynamic>? _eventSub;
  WebSocket? _eventSocket;

  /// Negotiates the protocol (spec §14.4) and returns the peer's facts.
  Future<HelloResult> hello({required LanSyncDeviceConfig local}) async {
    final payload = await _invoke('GET', '${LanSyncProtocol.apiPrefix}hello?protocolVersion=${local.protocolVersion}');
    return HelloResult(
      protocolVersion: switch (payload['protocolVersion']) {
        final num version => version.toInt(),
        _ => 0,
      },
      device: _object(payload['device']),
    );
  }

  /// Fetches the peer's published device facts.
  Future<Map<String, Object?>> device() async =>
      _object((await _invoke('GET', '${LanSyncProtocol.apiPrefix}device'))['device']);

  /// Sends a signed request to a registered route and decodes the JSON
  /// answer. This is the call the Phase 5 sync engine drives.
  Future<Map<String, Object?>> invoke(String method, String path, {Map<String, Object?>? body}) =>
      _invoke(method, '${LanSyncProtocol.apiPrefix}${path.startsWith('/') ? path.substring(1) : path}', body: body);

  /// Sends [bytes] as the raw body of a signed request — a file chunk — and
  /// decodes the JSON answer.
  Future<Map<String, Object?>> upload(String method, String path, List<int> bytes) =>
      _invoke(method, '${LanSyncProtocol.apiPrefix}${path.startsWith('/') ? path.substring(1) : path}', rawBody: bytes);

  /// The peer's event stream, over a pinned and signed WebSocket.
  ///
  /// The stream is broadcast: canceling a subscription never blocks on the
  /// close handshake, and the socket itself closes with [dispose].
  Stream<Map<String, Object?>> events() {
    var controller = _eventController;
    if (controller == null) {
      controller = StreamController<Map<String, Object?>>.broadcast();
      _eventController = controller;
      unawaited(_pumpEvents(controller));
    }
    return controller.stream;
  }

  /// Releases the HTTP client and closes the event socket.
  Future<void> dispose() async {
    await _eventSub?.cancel();
    _eventSub = null;
    await _eventSocket?.close();
    _eventSocket = null;
    await _eventController?.close();
    _eventController = null;
    _inner.close(force: true);
  }

  bool _pinned(X509Certificate certificate) =>
      KeyFingerprints.secureEquals(KeyFingerprints.sha256(certificate.der), pin);

  Future<void> _pumpEvents(StreamController<Map<String, Object?>> controller) async {
    try {
      final socket = await _connectEventSocket();
      _eventSocket = socket;
      _eventSub = socket.listen(
        (data) {
          if (controller.isClosed || data is! String) return;
          final decoded = jsonDecode(data);
          if (decoded is Map<Object?, Object?>) {
            controller.add(decoded.cast<String, Object?>());
          }
        },
        onError: (Object error) {
          if (!controller.isClosed) controller.addError(error);
        },
        onDone: () {
          if (!controller.isClosed) unawaited(controller.close());
        },
        cancelOnError: true,
      );
    } on Object catch (error) {
      if (!controller.isClosed) {
        controller.addError(error);
        await controller.close();
      }
    }
  }

  Future<WebSocket> _connectEventSocket() async {
    const path = '${LanSyncProtocol.apiPrefix}events';
    final timestamp = _now().millisecondsSinceEpoch;
    final nonce = RequestSigner.newNonce();
    final signature = RequestSigner.sign(
      canonical: LanSyncHttpAuth.canonical(
        method: 'WS',
        path: path,
        timestampMs: timestamp,
        nonce: nonce,
        bodySha256Hex: RequestSigner.bodyHash(const <int>[]),
      ),
      secret: await _secret(),
    );
    final uri = Uri(
      scheme: 'wss',
      host: host,
      port: port,
      path: path,
      queryParameters: <String, String>{
        LanSyncHttpAuth.deviceId: localDeviceId,
        LanSyncHttpAuth.timestamp: '$timestamp',
        LanSyncHttpAuth.nonce: nonce,
        'signature': signature,
      },
    );
    return await WebSocket.connect(uri.toString(), customClient: _inner);
  }

  Future<Map<String, Object?>> _invoke(
    String method,
    String pathWithQuery, {
    Map<String, Object?>? body,
    List<int>? rawBody,
  }) async {
    final bodyBytes = rawBody ?? (body == null ? const <int>[] : utf8.encode(jsonEncode(body)));
    final timestamp = _now().millisecondsSinceEpoch;
    final nonce = RequestSigner.newNonce();
    final uri = Uri.parse('https://$host:$port$pathWithQuery');
    final signature = RequestSigner.sign(
      canonical: LanSyncHttpAuth.canonical(
        method: method,
        path: LanSyncHttpAuth.target(uri),
        timestampMs: timestamp,
        nonce: nonce,
        bodySha256Hex: RequestSigner.bodyHash(bodyBytes),
      ),
      secret: await _secret(),
    );

    final HttpClientResponse response;
    try {
      final request = await _inner.openUrl(method, uri).timeout(requestTimeout);
      request.headers
        ..set(LanSyncHttpAuth.deviceId, localDeviceId)
        ..set(LanSyncHttpAuth.timestamp, '$timestamp')
        ..set(LanSyncHttpAuth.nonce, nonce)
        ..set(LanSyncHttpAuth.authorization, '${LanSyncHttpAuth.scheme} $signature');
      if (bodyBytes.isNotEmpty) {
        request
          ..headers.contentType = rawBody == null ? ContentType.json : ContentType.binary
          ..contentLength = bodyBytes.length
          ..add(bodyBytes);
      }
      response = await request.close().timeout(requestTimeout);
    } on LanSyncError {
      rethrow;
    } on Object catch (error) {
      final rejected = _rejectedFingerprint;
      _rejectedFingerprint = null;
      if (rejected != null) {
        // The handshake failed on the pin: someone else answers at this
        // address, or the peer's certificate changed. Never retryable.
        _log.error(
          'the device presented a different certificate',
          fields: {'device': peerDeviceId, 'presentedPrefix': rejected.substring(0, 19)},
        );
        throw LanSyncError(
          category: LanSyncErrorCategory.identityMismatch,
          code: 'peer_certificate_mismatch',
          message: 'The device presented a different certificate than when it was paired.',
          deviceId: peerDeviceId,
          debugContext: 'presented: $rejected',
        );
      }
      _log.warning('the device could not be reached', fields: {'device': peerDeviceId});
      throw LanSyncError(
        category: LanSyncErrorCategory.deviceUnavailable,
        code: 'peer_unreachable',
        message: 'The device could not be reached.',
        retryable: true,
        deviceId: peerDeviceId,
        debugContext: error.toString(),
      );
    }

    // Defense in depth: the handshake already enforced the pin; a response
    // that somehow arrives over another certificate is discarded unread.
    final certificate = response.certificate;
    if (certificate == null || !_pinned(certificate)) {
      await response.drain<void>();
      throw LanSyncError(
        category: LanSyncErrorCategory.identityMismatch,
        code: 'peer_certificate_mismatch',
        message: 'The device presented a different certificate than when it was paired.',
        deviceId: peerDeviceId,
      );
    }
    final responseBody = await _read(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpJson.errorFromResponse(response.statusCode, responseBody, deviceId: peerDeviceId);
    }
    return HttpJson.decodeObject(responseBody);
  }

  Future<List<int>> _read(HttpClientResponse response) async {
    final body = <int>[];
    await for (final chunk in response.timeout(requestTimeout)) {
      if (body.length + chunk.length > maxResponseBytes) {
        throw LanSyncError(
          category: LanSyncErrorCategory.dataValidation,
          code: 'response_too_large',
          message: 'The device answered with an oversized response.',
          deviceId: peerDeviceId,
        );
      }
      body.addAll(chunk);
    }
    return body;
  }

  Future<List<int>> _secret() async {
    final secret = await credentials.read(SecureKey.peerPairing(peerDeviceId));
    if (secret == null) {
      throw LanSyncError(
        category: LanSyncErrorCategory.authentication,
        code: 'no_pairing_secret',
        message: 'No pairing secret is held for the device; pair first.',
        deviceId: peerDeviceId,
      );
    }
    return secret;
  }

  static Map<String, Object?> _object(Object? value) => switch (value) {
    final Map<Object?, Object?> object => object.cast<String, Object?>(),
    _ => <String, Object?>{},
  };

  static const _invalidPin = LanSyncError(
    category: LanSyncErrorCategory.configuration,
    code: 'pin_invalid',
    message: 'The pinned certificate fingerprint is not a SHA-256 fingerprint.',
  );
}
