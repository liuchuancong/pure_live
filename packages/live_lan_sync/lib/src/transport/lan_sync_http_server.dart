import 'dart:async' show StreamController, unawaited;
import 'dart:convert' show jsonEncode;
import 'dart:io' show ContentType, HttpRequest, HttpServer, InternetAddress, WebSocket, WebSocketTransformer;
import 'dart:math' show min;
import 'dart:typed_data' show BytesBuilder, Uint8List;

import 'package:live_lan_sync/src/config/config.dart'
    show LanSyncDeviceConfig, LanSyncSecurityConfig, LanSyncServerConfig;
import 'package:live_lan_sync/src/domain/errors/errors.dart' show LanSyncError, LanSyncErrorCategory;
import 'package:live_lan_sync/src/domain/protocol/lan_sync_protocol.dart' show LanSyncProtocol;
import 'package:live_lan_sync/src/logging/logging.dart' show LanSyncLog, LanSyncLogArea, LanSyncLogger;
import 'package:live_lan_sync/src/pairing/pairing_responder.dart' show PairingResponder;
import 'package:live_lan_sync/src/security/secure_credential_store.dart' show SecureCredentialStore, SecureKey;
import 'package:live_lan_sync/src/security/tls_identity.dart' show TlsIdentity;
import 'package:live_lan_sync/src/store/store.dart' show LanSyncStore;
import 'package:live_lan_sync/src/transport/http_auth.dart' show LanSyncHttpAuth;
import 'package:live_lan_sync/src/transport/http_json.dart' show HttpJson;
import 'package:live_lan_sync/src/transport/replay_guard.dart' show ReplayGuard;
import 'package:live_lan_sync/src/transport/request_signer.dart' show RequestSigner;

/// A request arriving from an authenticated peer, handed to a route
/// handler.
final class PeerRequest {
  /// An authenticated peer request.
  const new({
    required this.senderDeviceId,
    required this.path,
    required this.body,
    this.bytes = const <int>[],
    this.pathParameters = const <String, String>{},
  });

  /// The verified sender.
  final String senderDeviceId;

  /// The full request path, including the API prefix.
  final String path;

  /// The decoded JSON body; empty for bodiless requests and raw routes.
  final Map<String, Object?> body;

  /// The raw body, signature-verified. Raw routes (file chunks) read it;
  /// JSON routes have [body].
  final List<int> bytes;

  /// The values of the route template's `{name}` segments, URL-decoded.
  final Map<String, String> pathParameters;
}

/// Handles one routed API call; the returned map is JSON-encoded into the
/// response. Throwing a [LanSyncError] maps to a typed error response.
typedef LanSyncRouteHandler = Future<Map<String, Object?>?> Function(PeerRequest request);

/// The most requests one sender may make inside the security config's rate
/// window. A bounded default, not a protocol constant (spec §21).
const int kLanSyncMaxRequestsPerWindow = 240;

/// The LAN sync server: one TLS listener serving the protocol API to paired
/// devices and the pairing ceremony to devices about to pair (spec §14).
///
/// TLS is mandatory (spec §9.1, §20): the listener presents [tlsIdentity],
/// whose fingerprint peers pinned during pairing. Every protocol request is
/// authenticated against the sender's trust record and the shared pairing
/// secret — an unpaired, revoked or mis-signing device never reaches a
/// route handler. `GET /hello` negotiates the protocol version,
/// `GET /device` answers with the local device facts, further routes plug
/// in through [route], and `GET /events` upgrades to a WebSocket that
/// receives [broadcast] events.
///
/// The pairing routes (`/pair/challenge`, `/pair/reveal`, `/pair/confirm`,
/// `/pair/status`) precede any shared secret, so they are not signed; the
/// [pairingResponder] admits them only while its pairing window is open,
/// and the server rate-limits them per remote address and caps their
/// bodies.
final class LanSyncHttpServer {
  /// A server over the given configuration and stores.
  new({
    required this.store,
    required this.credentials,
    required this.deviceConfig,
    required this.serverConfig,
    required this.tlsIdentity,
    this.securityConfig,
    this.pairingResponder,
    LanSyncLogger? logger,
    DateTime Function()? now,
  }) : _log = logger?.area(LanSyncLogArea.transport) ?? LanSyncLogger.silent.area(LanSyncLogArea.transport),
       _now = now ?? DateTime.now;

  /// The persistence the pairing and trust checks read.
  final LanSyncStore store;

  /// The secure storage holding the per-peer pairing secrets.
  final SecureCredentialStore credentials;

  /// The device facts this server publishes about itself.
  final LanSyncDeviceConfig deviceConfig;

  /// The listener parameters.
  final LanSyncServerConfig serverConfig;

  /// The certificate and key the listener presents.
  final TlsIdentity tlsIdentity;

  /// The security parameters (rate window, accepted protocol versions).
  final LanSyncSecurityConfig? securityConfig;

  /// The pairing ceremony's responder; null disables the pairing routes.
  final PairingResponder? pairingResponder;

  static const int _maxPairingBodyBytes = 16 * 1024;

  final DateTime Function() _now;
  final List<_Route> _routes = <_Route>[];
  final ReplayGuard _replayGuard = ReplayGuard();
  final Map<String, Map<String, int>> _requestCounts = <String, Map<String, int>>{};
  final Map<String, Set<WebSocket>> _eventSockets = <String, Set<WebSocket>>{};
  final StreamController<LanSyncError> _errors = StreamController<LanSyncError>.broadcast();
  final LanSyncLog _log;
  HttpServer? _server;

  /// The port the server bound after [start]; null before.
  int? get port => _server?.port;

  /// Whether the server is listening.
  bool get isRunning => _server != null;

  /// Diagnostic failures (bind refused, socket errors). Never request
  /// rejections — those travel as typed error responses.
  Stream<LanSyncError> get errors => _errors.stream;

  /// Binds the listener. Safe to call again while running.
  Future<void> start() async {
    if (_server != null) {
      return;
    }
    final address = serverConfig.listenOnAllInterfaces ? InternetAddress.anyIPv4 : InternetAddress.loopbackIPv4;
    final server = await HttpServer.bindSecure(address, serverConfig.port, tlsIdentity.serverContext());
    _server = server;
    _log.info('sync server listening', fields: {'port': server.port, 'tls': true});
    server.listen(_onRequest, onError: (Object error) => _report('server_socket', error));
  }

  /// Stops the listener and disconnects every event socket.
  Future<void> stop() async {
    final server = _server;
    _server = null;
    for (final sockets in _eventSockets.values) {
      for (final socket in sockets.toList()) {
        unawaited(socket.close());
      }
    }
    _eventSockets.clear();
    await server?.close(force: true);
    _log.info('sync server stopped');
  }

  /// Registers or replaces a route handler. [template] is relative to the
  /// API prefix; `{name}` segments capture path parameters, e.g.
  /// `route('PUT', 'files/{transferId}/chunks/{index}', handler)`.
  ///
  /// A [rawBody] route receives the body bytes as they arrived instead of
  /// a decoded JSON object — the signature covers them either way.
  void route(String method, String template, LanSyncRouteHandler handler, {bool rawBody = false}) {
    final segments = template.split('/').where((segment) => segment.isNotEmpty).toList(growable: false);
    _routes
      ..removeWhere((route) => route.method == method && route.sameTemplate(segments))
      ..add(_Route(method, segments, handler, rawBody: rawBody));
  }

  /// Pushes an event to every connected peer's event socket.
  void broadcast(Map<String, Object?> event) {
    final payload = jsonEncode(event);
    for (final sockets in _eventSockets.values) {
      for (final socket in sockets.toList()) {
        try {
          socket.add(payload);
        } on Object {
          unawaited(socket.close());
          sockets.remove(socket);
        }
      }
    }
  }

  /// Releases the listener and closes the diagnostic stream.
  Future<void> dispose() async {
    await stop();
    await _errors.close();
  }

  Future<void> _onRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (path == '${LanSyncProtocol.apiPrefix}events') {
        await _handleEventSocket(request);
        return;
      }
      if (path.startsWith('${LanSyncProtocol.apiPrefix}pair/')) {
        await _handlePairing(request, path.substring(LanSyncProtocol.apiPrefix.length));
        return;
      }
      if (!path.startsWith(LanSyncProtocol.apiPrefix)) {
        await _answer(
          request,
          404,
          const LanSyncError(
            category: LanSyncErrorCategory.dataValidation,
            code: 'unknown_path',
            message: 'The path is outside the sync API.',
          ),
        );
        return;
      }
      final sender = request.headers.value(LanSyncHttpAuth.deviceId);
      if (sender == null || sender.isEmpty) {
        await _answer(
          request,
          401,
          const LanSyncError(
            category: LanSyncErrorCategory.authentication,
            code: 'sender_missing',
            message: 'The request does not name a sender device.',
          ),
        );
        return;
      }
      final body = await _readBody(request, serverConfig.maxRequestBodyBytes);
      if (body == null) {
        await _answer(request, 413, _tooLarge);
        return;
      }
      final failure = await _authenticate(request, sender, body);
      if (failure != null) {
        await _answer(request, failure.$2, failure.$1);
        return;
      }
      await _routeAuthenticated(request, sender, body);
    } on LanSyncError catch (error) {
      if (_refusalLevels.contains(_statusFor(error))) {
        _log.warning(
          'request refused',
          fields: {
            'code': error.code,
            'device': ?error.deviceId,
            'status': _statusFor(error),
            'path': _routeOf(request),
          },
        );
      }
      await _safeAnswer(request, _statusFor(error), error);
    } on Object catch (error) {
      _report('request_handling', error);
      await _safeAnswer(
        request,
        500,
        const LanSyncError(
          category: LanSyncErrorCategory.transport,
          code: 'internal_error',
          message: 'The request could not be served.',
        ),
      );
    }
  }

  Future<void> _handlePairing(HttpRequest request, String route) async {
    final responder = pairingResponder;
    if (responder == null) {
      await _answer(
        request,
        404,
        const LanSyncError(
          category: LanSyncErrorCategory.permissionDenied,
          code: 'pairing_unavailable',
          message: 'This device does not accept pairing.',
        ),
      );
      return;
    }
    final address = request.connectionInfo?.remoteAddress.address ?? 'unknown';
    if (!_requestAllowed('pair:$address')) {
      await _answer(
        request,
        429,
        const LanSyncError(
          category: LanSyncErrorCategory.rateLimited,
          code: 'too_many_requests',
          message: 'Too many pairing requests; slow down.',
        ),
      );
      return;
    }
    if (request.method != 'POST') {
      await _answer(request, 405, _unknownRoute);
      return;
    }
    final body = await _readBody(request, min(serverConfig.maxRequestBodyBytes, _maxPairingBodyBytes));
    if (body == null) {
      await _answer(request, 413, _tooLarge);
      return;
    }
    final json = HttpJson.decodeObject(body);
    final answer = switch (route) {
      'pair/challenge' => await responder.handleChallenge(json, remoteAddress: address),
      'pair/reveal' => await responder.handleReveal(json),
      'pair/confirm' => await responder.handleConfirm(json),
      'pair/status' => responder.handleStatus(json),
      _ => null,
    };
    if (answer == null) {
      await _answer(request, 404, _unknownRoute);
      return;
    }
    await _json(request, answer);
  }

  /// Verifies pairing, rate limit, timestamp, nonce and signature. Returns
  /// the (error, status) to answer with, or null when authenticated.
  Future<(LanSyncError, int)?> _authenticate(HttpRequest request, String sender, Uint8List body) async {
    final trust = await store.deviceTrust(sender);
    if (trust == null || trust.revoked) {
      return (_notPaired, 401);
    }
    if (!_requestAllowed(sender)) {
      return (
        const LanSyncError(
          category: LanSyncErrorCategory.rateLimited,
          code: 'too_many_requests',
          message: 'The device sent too many requests; slow down.',
        ),
        429,
      );
    }
    final timestampHeader = request.headers.value(LanSyncHttpAuth.timestamp);
    final nonce = request.headers.value(LanSyncHttpAuth.nonce);
    final authorization = request.headers.value(LanSyncHttpAuth.authorization) ?? '';
    final timestamp = timestampHeader == null ? null : int.tryParse(timestampHeader);
    if (timestamp == null || nonce == null || nonce.isEmpty) {
      return (_headersMissing, 401);
    }
    if (!_replayGuard.accept(sender: sender, timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp), nonce: nonce)) {
      return (_replayed, 401);
    }
    final secret = await credentials.read(SecureKey.peerPairing(sender));
    if (secret == null) {
      return (
        const LanSyncError(
          category: LanSyncErrorCategory.authentication,
          code: 'no_pairing_secret',
          message: 'No pairing secret is held for the sender.',
        ),
        401,
      );
    }
    final canonical = LanSyncHttpAuth.canonical(
      method: request.method,
      path: LanSyncHttpAuth.target(request.uri),
      timestampMs: timestamp,
      nonce: nonce,
      bodySha256Hex: RequestSigner.bodyHash(body),
    );
    final signature = authorization.startsWith('${LanSyncHttpAuth.scheme} ')
        ? authorization.substring(LanSyncHttpAuth.scheme.length + 1)
        : '';
    if (!RequestSigner.verify(canonical: canonical, signature: signature, secret: secret)) {
      return (_badSignature, 401);
    }
    return null;
  }

  Future<void> _routeAuthenticated(HttpRequest request, String sender, Uint8List body) async {
    final path = request.uri.path;
    if (request.method == 'GET' && path == '${LanSyncProtocol.apiPrefix}hello') {
      await _json(request, _helloPayload(request));
      return;
    }
    if (request.method == 'GET' && path == '${LanSyncProtocol.apiPrefix}device') {
      await _json(request, <String, Object?>{'device': _deviceFacts()});
      return;
    }
    final relative = request.uri.pathSegments.skip(_prefixSegments).toList(growable: false);
    for (final route in _routes) {
      final parameters = route.match(request.method, relative);
      if (parameters == null) continue;
      final result = await route.handler(
        PeerRequest(
          senderDeviceId: sender,
          path: path,
          body: route.rawBody ? const <String, Object?>{} : HttpJson.decodeObject(body),
          bytes: body,
          pathParameters: parameters,
        ),
      );
      await _json(request, result ?? <String, Object?>{});
      return;
    }
    await _answer(request, 404, _unknownRoute);
  }

  static final int _prefixSegments = Uri.parse(LanSyncProtocol.apiPrefix).pathSegments
      .where((s) => s.isNotEmpty)
      .length;

  /// Protocol negotiation (spec §14.4): the caller states the version it
  /// speaks through `?protocolVersion=`; anything this device does not
  /// accept is an explicit conflict, never a silent reinterpretation.
  Map<String, Object?> _helloPayload(HttpRequest request) {
    final requested = int.tryParse(request.uri.queryParameters['protocolVersion'] ?? '');
    final supported = securityConfig?.allowedProtocolVersions ?? const <int>{LanSyncProtocol.current};
    if (requested == null || !supported.contains(requested)) {
      throw LanSyncError(
        category: LanSyncErrorCategory.protocolIncompatible,
        code: 'protocol_version_unsupported',
        message: 'The protocol version is not supported by this device.',
        debugContext: 'requested: $requested, supported: ${supported.toList()..sort()}',
      );
    }
    return <String, Object?>{'protocolVersion': LanSyncProtocol.current, 'device': _deviceFacts()};
  }

  Map<String, Object?> _deviceFacts() => <String, Object?>{
    'deviceId': deviceConfig.deviceId,
    'deviceName': deviceConfig.deviceName,
    'platform': deviceConfig.platform,
    'appVersion': deviceConfig.appVersion,
    'protocolVersion': deviceConfig.protocolVersion,
    'tlsFingerprint': tlsIdentity.fingerprint,
  };

  bool _requestAllowed(String key) {
    final window = securityConfig?.rateLimitWindow ?? const Duration(minutes: 1);
    final bucket = _now().millisecondsSinceEpoch ~/ window.inMilliseconds;
    final counts = _requestCounts.putIfAbsent(key, () => <String, int>{})..removeWhere((slot, _) => slot != '$bucket');
    final count = counts.putIfAbsent('$bucket', () => 0);
    if (count >= kLanSyncMaxRequestsPerWindow) {
      return false;
    }
    counts['$bucket'] = count + 1;
    return true;
  }

  Future<void> _handleEventSocket(HttpRequest request) async {
    final parameters = request.uri.queryParameters;
    final sender = parameters[LanSyncHttpAuth.deviceId];
    final timestamp = int.tryParse(parameters[LanSyncHttpAuth.timestamp] ?? '');
    final nonce = parameters[LanSyncHttpAuth.nonce];
    final signature = parameters['signature'] ?? '';
    if (sender == null || timestamp == null || nonce == null || nonce.isEmpty) {
      await _answer(request, 401, _headersMissing);
      return;
    }
    final trust = await store.deviceTrust(sender);
    if (trust == null || trust.revoked) {
      await _answer(request, 401, _notPaired);
      return;
    }
    if (!_replayGuard.accept(sender: sender, timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp), nonce: nonce)) {
      await _answer(request, 401, _replayed);
      return;
    }
    final secret = await credentials.read(SecureKey.peerPairing(sender));
    final canonical = LanSyncHttpAuth.canonical(
      method: 'WS',
      path: '${LanSyncProtocol.apiPrefix}events',
      timestampMs: timestamp,
      nonce: nonce,
      bodySha256Hex: RequestSigner.bodyHash(const <int>[]),
    );
    if (secret == null || !RequestSigner.verify(canonical: canonical, signature: signature, secret: secret)) {
      await _answer(request, 401, _badSignature);
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    final sockets = _eventSockets.putIfAbsent(sender, () => <WebSocket>{})..add(socket);
    socket.listen(
      (_) {},
      onDone: () => sockets.remove(socket),
      onError: (Object _) => sockets.remove(socket),
      cancelOnError: true,
    );
  }

  static Future<Uint8List?> _readBody(HttpRequest request, int maxBytes) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      if (builder.length + chunk.length > maxBytes) {
        return null;
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  static int _statusFor(LanSyncError error) => switch (error.category) {
    LanSyncErrorCategory.authentication || LanSyncErrorCategory.identityMismatch => 401,
    LanSyncErrorCategory.permissionDenied => 403,
    LanSyncErrorCategory.rateLimited => 429,
    LanSyncErrorCategory.protocolIncompatible ||
    LanSyncErrorCategory.schemaIncompatible ||
    LanSyncErrorCategory.pairing => 409,
    LanSyncErrorCategory.timeout => 408,
    LanSyncErrorCategory.dataValidation => 400,
    LanSyncErrorCategory.insufficientStorage => 507,
    _ => 500,
  };

  static Future<void> _json(HttpRequest request, Map<String, Object?> payload) async {
    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(payload));
    await request.response.close();
  }

  static Future<void> _answer(HttpRequest request, int status, LanSyncError error) async {
    request.response
      ..headers.contentType = ContentType.json
      ..statusCode = status
      ..write(jsonEncode(<String, Object?>{'error': error.toJson()}));
    await request.response.close();
  }

  static Future<void> _safeAnswer(HttpRequest request, int status, LanSyncError error) async {
    try {
      await _answer(request, status, error);
    } on Object {
      // The socket is gone; nothing to answer.
    }
  }

  void _report(String stage, Object error) {
    if (_errors.isClosed) {
      return;
    }
    _errors.add(
      LanSyncError(
        category: LanSyncErrorCategory.transport,
        code: 'server_failure',
        message: 'The sync server hit a transport failure.',
        stage: stage,
        debugContext: error.toString(),
      ),
    );
  }

  static const _notPaired = LanSyncError(
    category: LanSyncErrorCategory.authentication,
    code: 'peer_not_paired',
    message: 'The device is not paired, or the pairing was revoked.',
  );

  static const _headersMissing = LanSyncError(
    category: LanSyncErrorCategory.authentication,
    code: 'auth_headers_missing',
    message: 'The request lacks authentication headers.',
  );

  static const _replayed = LanSyncError(
    category: LanSyncErrorCategory.authentication,
    code: 'replayed_or_stale_request',
    message: 'The request is stale or repeats an earlier request.',
  );

  static const _badSignature = LanSyncError(
    category: LanSyncErrorCategory.authentication,
    code: 'signature_invalid',
    message: 'The request signature did not verify.',
  );

  static const _tooLarge = LanSyncError(
    category: LanSyncErrorCategory.dataValidation,
    code: 'request_too_large',
    message: 'The request body exceeds the configured limit.',
  );

  static const _unknownRoute = LanSyncError(
    category: LanSyncErrorCategory.protocolIncompatible,
    code: 'unknown_route',
    message: 'The route does not exist on this device.',
  );

  /// Refusals worth a line: authentication, permission, rate limiting.
  /// Validation noise and the catch-all stay out.
  static const _refusalLevels = <int>{401, 403, 429};

  /// The route of [request] with parameter values collapsed, e.g.
  /// `PUT files/{id}/chunks/{index}` — enough to diagnose, no payload.
  String _routeOf(HttpRequest request) {
    final segments = request.uri.pathSegments.skip(2).toList(growable: false);
    if (segments.length >= 3 && segments[0] == 'files' && segments[2] == 'chunks') {
      return '${request.method} files/{id}/chunks/{index}';
    }
    if (segments.length >= 2 && segments[0] == 'files') {
      return '${request.method} files/{id}/${segments.skip(2).join('/')}';
    }
    return '${request.method} ${segments.join('/')}';
  }
}

/// One registered route: a method, a template of literal and `{name}`
/// segments, and its handler.
final class _Route {
  new(this.method, this.segments, this.handler, {required this.rawBody});

  final String method;
  final List<String> segments;
  final LanSyncRouteHandler handler;
  final bool rawBody;

  bool sameTemplate(List<String> other) =>
      other.length == segments.length &&
      [for (var i = 0; i < other.length; i++) other[i] == segments[i]].every((same) => same);

  /// The captured parameters when [method] and [path] match, else null.
  Map<String, String>? match(String method, List<String> path) {
    if (method != this.method || path.length != segments.length) return null;
    final parameters = <String, String>{};
    for (var i = 0; i < segments.length; i++) {
      final template = segments[i];
      if (template.length > 2 && template.startsWith('{') && template.endsWith('}')) {
        if (path[i].isEmpty) return null;
        parameters[template.substring(1, template.length - 1)] = path[i];
      } else if (template != path[i]) {
        return null;
      }
    }
    return parameters;
  }
}
