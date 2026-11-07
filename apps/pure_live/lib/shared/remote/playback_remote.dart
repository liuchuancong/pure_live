import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import 'package:pure_live/shared/remote/playback_target.dart';
import 'package:pure_live/shared/remote/remote_web.dart';

String _nonce() => base64Url.encode(List<int>.generate(32, (_) => Random.secure().nextInt(256))).replaceAll('=', '');

/// The first non-loopback IPv4 on this machine, else empty: what a phone on
/// the same network can reach.
Future<String> bestLanAddress() async {
  try {
    final interfaces = await NetworkInterface.list();
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4 && !address.isLoopback) return address.address;
      }
    }
  } on Object {
    // Fall through to empty; the manual address and the QR keep working when
    // the viewer types one.
  }
  return '';
}

/// Explicitly enabled LAN playback control (「局域网遥控」). A phone's browser
/// pairs with the six-digit code shown only on this device, then drives the
/// registered playback pages; system capture has separate local consent.
///
/// No settings, account, file or arbitrary URL endpoint is exposed: the
/// commands are a fixed whitelist, the text and link endpoints are length-
/// capped, and the target id must match what the phone last saw, so queued
/// input for a gone page cannot spill onto the next one (the ETag of the
/// interface revision).
final class PlaybackRemote extends ChangeNotifier {
  /// Creates a stopped receiver. [now] is replaceable for expiry tests.
  PlaybackRemote({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final List<RemotePlaybackTarget> _targets = [];
  final Map<String, DateTime> _sessions = {};
  final Map<String, String> _sessionPeers = {};
  HttpServer? _server;
  RawDatagramSocket? _discovery;
  String _code = '';
  int _wrongCodes = 0;
  DateTime? _blockedUntil;
  bool _busy = false;
  int _generation = 0;
  Future<void>? _starting;
  Map<String, String> _labels = const {};

  /// Supported commands; the target advertises its applicable subset.
  static const commands = {
    'play',
    'pause',
    'refresh',
    'previous',
    'next',
    'volume',
    'mute',
    'fullscreen',
    'danmaku',
    'up',
    'down',
    'left',
    'right',
    'ok',
    'back',
    'home',
  };

  /// Discovery is separate from settings sync's UDP port 39889.
  static const discoveryPort = 39891;

  /// Ephemeral id, independent of the account or settings-sync identity.
  final String id = _nonce();

  /// The six-digit pairing code shown only on the receiving device.
  String get code => _code;

  /// Whether remote commands are currently accepted.
  bool get running => _server != null;

  /// Bound HTTP port; zero while stopped.
  int get port => _server?.port ?? 0;

  /// The selected LAN IPv4 address, without account data.
  String address = '';

  /// Browser and QR entry point. The URL deliberately carries no pairing code.
  String get url => running && address.isNotEmpty ? 'http://$address:$port/' : '';

  /// Number of paired sessions still within their twelve-hour lifetime.
  int get pairedCount {
    _expire();
    return _sessions.length;
  }

  /// Resolves a supported live-room share text and opens it. The generation
  /// check must be tested again after any asynchronous link resolution.
  Future<bool> Function(String text, bool Function() authorized)? onLink;

  /// Invalidates queued input when focus, route, popup or overlay changes.
  int Function()? scopeRevision;

  /// Application fallback, available outside playback and over its dialogs.
  RemotePlaybackTarget? applicationTarget;

  /// Explicit local consent or a system picker suspends all remote input.
  bool Function()? inputBlocked;

  /// Inserts text without reading or exporting the focused field's contents.
  Future<bool> Function(String text, int inputId)? onText;

  /// Adds a page. Newest visible targets take precedence over covered pages.
  void register(RemotePlaybackTarget target) => _targets.add(target);

  /// Removes precisely [target], including a page underneath a newer player.
  void unregister(RemotePlaybackTarget target) => _targets.remove(target);

  String _targetId(RemotePlaybackTarget target) =>
      scopeRevision == null ? target.id : '${target.id}:${scopeRevision!()}';

  RemotePlaybackTarget? get _target {
    if (inputBlocked?.call() ?? false) return null;
    final page = _targets.reversed.where((target) => target.available()).firstOrNull;
    return page;
  }

  /// Enables this receiver until explicitly stopped or the app exits.
  /// [labels] words the browser page; they are read from the app's own
  /// translations at start time.
  Future<void> start({Map<String, String> labels = const {}, InternetAddress? bind, bool discovery = true}) =>
      _starting ??= _start(labels: labels, bind: bind, discovery: discovery).whenComplete(() => _starting = null);

  Future<void> _start({required Map<String, String> labels, required bool discovery, InternetAddress? bind}) async {
    if (running) return;
    final generation = ++_generation;
    final server = await HttpServer.bind(bind ?? InternetAddress.anyIPv4, 0);
    if (generation != _generation) {
      await server.close(force: true);
      return;
    }
    _server = server;
    _labels = labels;
    address = await bestLanAddress();
    if (!identical(_server, server)) return;
    revoke();
    server.listen((request) => unawaited(_handle(request)));
    if (discovery) await _startDiscovery(generation);
    notifyListeners();
  }

  Future<void> _startDiscovery(int generation) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort);
      if (generation != _generation || !running) {
        socket.close();
        return;
      }
      _discovery = socket;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? packet;
        while ((packet = socket.receive()) != null) {
          final message = packet!;
          if (message.data.length != 27 ||
              ascii.decode(message.data, allowInvalid: true) != 'purelive-remote-discover-v1') {
            continue;
          }
          final data = utf8.encode(
            jsonEncode({'protocol': 'purelive-remote-v1', 'id': id, 'name': Platform.localHostname, 'port': port}),
          );
          socket.send(data, message.address, message.port);
        }
      });
    } on Object {
      // Manual address / browser / QR remain usable on isolated Wi-Fi or when
      // another local instance already owns the UDP discovery port.
    }
  }

  /// Revokes every paired controller immediately and rotates the pairing code.
  void revoke() {
    _generation++;
    _sessions.clear();
    _sessionPeers.clear();
    _code = (100000 + Random.secure().nextInt(900000)).toString();
    _wrongCodes = 0;
    notifyListeners();
  }

  void _expire() {
    final expired = _sessions.entries.where((entry) => !entry.value.isAfter(_now())).map((entry) => entry.key).toList();
    for (final token in expired) {
      _sessions.remove(token);
      _sessionPeers.remove(token);
    }
  }

  bool _authorized(HttpRequest request) {
    _expire();
    final auth = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    if (!auth.startsWith('Bearer ') || !_sessions.containsKey(auth.substring(7))) return false;
    final peer = request.connectionInfo?.remoteAddress.address;
    if (peer != null) _sessionPeers[auth.substring(7)] = peer;
    return true;
  }

  Future<Map<String, dynamic>> _json(HttpRequest request) async {
    final json = request.headers.contentType?.mimeType == 'application/json';
    const limit = 16384;
    final elapsed = Stopwatch()..start();
    final bytes = <int>[];
    var received = 0;
    var oversized = false;
    await for (final chunk in request.timeout(const Duration(seconds: 10))) {
      received += chunk.length;
      // Cancelling the input on the first excess chunk may reset the socket
      // before the 400 headers arrive. Drain only a bounded excess, with no
      // excess stored and no unbounded stream kept alive by periodic chunks.
      if (received > limit + 65536) throw const FormatException('body read budget exceeded');
      if (elapsed.elapsed > const Duration(seconds: 10)) throw TimeoutException('body read deadline');
      if (received > limit) {
        oversized = true;
        bytes.clear();
      } else if (!oversized && json) {
        bytes.addAll(chunk);
      }
    }
    if (!json) throw const FormatException('json required');
    if (oversized) throw const FormatException('oversized');
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, dynamic>) throw const FormatException('object required');
    return value;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response
      ..persistentConnection = false
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..headers.set('x-content-type-options', 'nosniff')
      ..headers.set('x-frame-options', 'DENY')
      ..headers.set('referrer-policy', 'no-referrer');
    try {
      // Consume bounded JSON before replying, including rejected origins and
      // sessions. Leaving a POST body unread can reset a reused HTTP connection.
      final payload = request.method == 'POST' ? await _json(request) : null;
      final origin = request.headers.value('origin');
      final host = request.headers.value(HttpHeaders.hostHeader);
      if (origin != null && origin != 'http://$host') {
        response.statusCode = HttpStatus.forbidden;
      } else if (request.method == 'GET' && request.uri.path == '/') {
        response.headers.contentType = ContentType.html;
        response.headers.set(
          'content-security-policy',
          "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; img-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
        );
        response.write(remoteControlHtml(labels: _labels));
      } else if (request.method == 'POST' && request.uri.path == '/api/pair') {
        final data = payload!;
        if (_blockedUntil?.isAfter(_now()) ?? false) {
          response.statusCode = HttpStatus.tooManyRequests;
        } else if (data['code'] != _code) {
          response.statusCode = HttpStatus.forbidden;
          if (++_wrongCodes >= 10) {
            _blockedUntil = _now().add(const Duration(minutes: 1));
            revoke();
          }
        } else if (pairedCount >= 8) {
          response.statusCode = HttpStatus.tooManyRequests;
        } else {
          final token = _nonce();
          _sessions[token] = _now().add(const Duration(hours: 12));
          final peer = request.connectionInfo?.remoteAddress.address;
          if (peer != null) _sessionPeers[token] = peer;
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode({'token': token, 'name': Platform.localHostname}));
          notifyListeners();
        }
      } else if (!_authorized(request)) {
        response.statusCode = HttpStatus.unauthorized;
      } else if (request.method == 'GET' && request.uri.path == '/api/status') {
        final target = _target;
        response.headers.contentType = ContentType.json;
        response.write(
          jsonEncode({'targetId': target == null ? null : _targetId(target), 'state': target?.snapshot()}),
        );
      } else if (request.method == 'POST' && request.uri.path == '/api/unpair') {
        final token = request.headers.value(HttpHeaders.authorizationHeader)!.substring(7);
        _sessions.remove(token);
        _sessionPeers.remove(token);
        notifyListeners();
      } else if (request.method == 'POST' && request.uri.path == '/api/command') {
        final data = payload!;
        final target = _target;
        final command = data['command'];
        final value = data['value'];
        final targetId = target == null ? null : _targetId(target);
        if (target == null || targetId != data['targetId']) {
          response.statusCode = HttpStatus.conflict;
        } else if (command is! String ||
            !commands.contains(command) ||
            (value != null && (value is! num || !value.isFinite || value < 0 || value > 1))) {
          response.statusCode = HttpStatus.badRequest;
        } else if (!(target.snapshot()['commands'] as List? ?? const <String>[]).contains(command)) {
          response.statusCode = HttpStatus.conflict;
        } else if (_busy) {
          response.statusCode = HttpStatus.conflict;
        } else {
          _busy = true;
          try {
            if (!await target.execute(command, (value as num?)?.toDouble())) {
              response.statusCode = HttpStatus.conflict;
            }
          } finally {
            _busy = false;
          }
        }
      } else if (request.method == 'POST' && request.uri.path == '/api/text') {
        final data = payload!;
        final target = _target;
        final text = data['text'];
        final inputId = data['inputId'];
        final targetId = target == null ? null : _targetId(target);
        if (target == null || targetId != data['targetId']) {
          response.statusCode = HttpStatus.conflict;
        } else if (text is! String || text.length > 4096 || inputId is! int) {
          response.statusCode = HttpStatus.badRequest;
        } else if (await onText?.call(text, inputId) != true) {
          response.statusCode = HttpStatus.conflict;
        }
      } else if (request.method == 'POST' && request.uri.path == '/api/link') {
        final data = payload!;
        final text = data['text'];
        if (inputBlocked?.call() ?? false) {
          response.statusCode = HttpStatus.conflict;
        } else if (text is! String || text.isEmpty || text.length > 4096) {
          response.statusCode = HttpStatus.badRequest;
        } else if (_busy) {
          response.statusCode = HttpStatus.conflict;
        } else {
          final generation = _generation;
          _busy = true;
          try {
            final opened = await onLink?.call(
              text,
              () => running && generation == _generation && _authorized(request) && !(inputBlocked?.call() ?? false),
            );
            if (opened != true) response.statusCode = HttpStatus.unprocessableEntity;
          } finally {
            _busy = false;
          }
        }
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } on FormatException {
      response.statusCode = HttpStatus.badRequest;
    } on TimeoutException {
      response.statusCode = HttpStatus.requestTimeout;
    } on Object {
      response.statusCode = HttpStatus.serviceUnavailable;
    }
    try {
      await response.close();
    } on Object {
      // The controller may disconnect while a command is being handled.
    }
  }

  /// Disables receiving, revokes all sessions, and closes discovery sockets.
  Future<void> stop() async {
    _generation++;
    final server = _server;
    _server = null;
    _discovery?.close();
    _discovery = null;
    _sessions.clear();
    _sessionPeers.clear();
    _code = '';
    await server?.close(force: true);
    notifyListeners();
  }
}
