import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_stream.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_watch.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// One caller-owned seat, without hidden reconnect using an expired bootstrap.
/// Callers observe [done], reacquire metadata if appropriate, and explicitly
/// close on exit. Playback and recording must not share ownership of a seat.
class NiconicoSession {
  NiconicoSession._(
    this._uri,
    this._connector,
    this._findProxy,
    this.startupTimeout,
    this.silenceTimeout,
    this.closeTimeout,
  );
  final Uri _uri;
  final WebSocketConnector _connector;
  final String Function(Uri) _findProxy;
  final Duration startupTimeout;
  final Duration silenceTimeout;
  final Duration closeTimeout;
  final _first = Completer<void>();
  final _done = Completer<NiconicoFailure?>();
  final _changes = StreamController<NiconicoStream>.broadcast();
  WebSocketChannel? _channel;
  io.HttpClient? _httpClient;
  StreamSubscription<dynamic>? _subscription;
  StreamSubscription<dynamic>? _cancellation;
  Timer? _startupTimer;
  Timer? _seatTimer;
  Timer? _silenceTimer;
  NiconicoStream? _current;
  Future<void>? _closing;
  NiconicoFailure? _failure;
  bool _closed = false;
  bool _hasSeat = false;
  bool _cleanupSucceeded = false;
  int? _seatIntervalSeconds;
  int _seatKeepAlivesSent = 0;
  int _pongsSent = 0;

  bool get isClosed => _closed;
  bool get cleanupSucceeded => _cleanupSucceeded;
  int? get seatIntervalSeconds => _seatIntervalSeconds;
  int get seatKeepAlivesSent => _seatKeepAlivesSent;
  int get pongsSent => _pongsSent;
  Future<NiconicoFailure?> get done => _done.future;
  Stream<NiconicoStream> get changes => _changes.stream;
  NiconicoStream get current {
    if (_closed || !_hasSeat || _current == null) throw const NiconicoException(NiconicoFailure.sessionClosed);
    return _current!;
  }

  static Future<NiconicoSession> open(
    NiconicoWatch watch, {
    CancelToken? cancel,
    WebSocketConnector connector = _connect,
    String Function(Uri)? findProxy,
    Duration startupTimeout = const Duration(seconds: 20),
    Duration silenceTimeout = const Duration(seconds: 90),
    Duration closeTimeout = const Duration(seconds: 2),
  }) async {
    if (cancel?.isCancelled == true) throw const NiconicoException(NiconicoFailure.cancelled);
    if (watch.status != NiconicoStatus.onAir) throw const NiconicoException(NiconicoFailure.notLive);
    if (watch.access != NiconicoAccess.allowed) throw const NiconicoException(NiconicoFailure.access);
    final uri = watch.webSocketUri;
    if (uri == null ||
        uri.scheme != 'wss' ||
        uri.host != 'a.live2.nicovideo.jp' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment ||
        !RegExp(r'^/(?:unama/)?wsapi/v2/watch/[1-9][0-9]*$').hasMatch(uri.path)) {
      throw const NiconicoException(NiconicoFailure.schema);
    }
    if (startupTimeout <= Duration.zero || silenceTimeout <= Duration.zero || closeTimeout <= Duration.zero) {
      throw ArgumentError('Session timeouts must be positive');
    }
    final session = NiconicoSession._(
      uri,
      connector,
      findProxy ?? resolveWebSocketProxyDirective,
      startupTimeout,
      silenceTimeout,
      closeTimeout,
    );
    session._cancellation = cancel?.whenCancel.asStream().listen((_) => session._end(NiconicoFailure.cancelled));
    session._startupTimer = Timer(startupTimeout, () => session._end(NiconicoFailure.transport));
    unawaited(session._handshake());
    try {
      await session._first.future;
      if (session._closed) throw NiconicoException(session._failure ?? NiconicoFailure.sessionClosed);
      return session;
    } catch (_) {
      await session.close();
      if (!session.cleanupSucceeded) throw const NiconicoException(NiconicoFailure.cleanup);
      rethrow;
    }
  }

  static WebSocketChannel _connect(
    String endpoint, {
    Duration? connectTimeout,
    Iterable<String>? protocols,
    Map<String, dynamic>? headers,
    io.HttpClient? customClient,
  }) => IOWebSocketChannel.connect(
    endpoint,
    connectTimeout: connectTimeout,
    protocols: protocols,
    headers: headers,
    customClient: customClient,
  );

  Future<void> _handshake() async {
    io.HttpClient? client;
    try {
      final directive = _findProxy(_uri);
      if (directive != 'DIRECT') {
        client = io.HttpClient()..findProxy = (_) => directive;
        _httpClient = client;
      }
      final channel = _connector(
        _uri.toString(),
        connectTimeout: startupTimeout,
        headers: const {'Origin': 'https://live.nicovideo.jp'},
        customClient: client,
      );
      _channel = channel;
      // The single startup timer belongs to the session. A separate ready
      // timeout would outlive cancellation while an upgrade remains pending.
      await Future.any<void>([channel.ready, _done.future.then<void>((_) {})]);
      if (_closed) return;
      _subscription = channel.stream.listen(
        _receive,
        onError: (Object _) => _end(NiconicoFailure.transport),
        onDone: () => _end(NiconicoFailure.sessionClosed),
      );
      _resetSilence();
      _send({
        'type': 'startWatching',
        'data': {
          'stream': {'quality': 'abr', 'protocol': 'hls', 'latency': 'high', 'chasePlay': false},
          'room': {'protocol': 'webSocket', 'commentable': false},
          'reconnect': false,
        },
      });
      _send({
        'type': 'getAkashic',
        'data': {'chasePlay': false},
      });
    } catch (_) {
      _end(NiconicoFailure.transport);
    } finally {
      client?.close(force: _closed);
      if (identical(_httpClient, client)) _httpClient = null;
    }
  }

  void _resetSilence() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(silenceTimeout, () => _end(NiconicoFailure.transport));
  }

  void _receive(dynamic frame) {
    if (_closed) return;
    try {
      if (frame is! String || frame.length > 1024 * 1024 || utf8.encode(frame).length > 1024 * 1024) {
        throw const NiconicoException(NiconicoFailure.schema);
      }
      final message = jsonDecode(frame);
      if (message is! Map<String, dynamic> || message['type'] is! String) {
        throw const NiconicoException(NiconicoFailure.schema);
      }
      _resetSilence();
      final data = message['data'];
      switch (message['type']) {
        case 'ping':
          if (_send({'type': 'pong'})) _pongsSent++;
          _keepSeat();
        case 'seat':
          final seconds = data is Map ? data['keepIntervalSec'] : null;
          if (seconds is! int || seconds < 1 || seconds > 300) throw const NiconicoException(NiconicoFailure.schema);
          _hasSeat = true;
          _seatIntervalSeconds = seconds;
          _seatTimer?.cancel();
          _seatTimer = Timer.periodic(Duration(seconds: seconds), (_) => _keepSeat());
          _readyIfComplete();
        case 'stream':
          if (data is! Map<String, dynamic>) throw const NiconicoException(NiconicoFailure.schema);
          final next = NiconicoStream.parse(data);
          _current?.close();
          _current = next;
          _readyIfComplete();
          _changes.add(next);
        case 'error':
          _end(NiconicoFailure.sessionError);
        case 'disconnect':
          _end(NiconicoFailure.sessionClosed);
        // serverTime and other auxiliary messages carry no media permission.
      }
    } catch (error) {
      _end(error is NiconicoException ? error.kind : NiconicoFailure.schema);
    }
  }

  void _readyIfComplete() {
    if (_hasSeat && _current != null && !_first.isCompleted) {
      _startupTimer?.cancel();
      _first.complete();
    }
  }

  bool _send(Map<String, Object?> message) {
    if (_closed) return false;
    try {
      _channel!.sink.add(jsonEncode(message));
      return true;
    } catch (_) {
      _end(NiconicoFailure.transport);
      return false;
    }
  }

  void _keepSeat() {
    if (_hasSeat && _send({'type': 'keepSeat'})) _seatKeepAlivesSent++;
  }

  void _end(NiconicoFailure reason) {
    if (_closed) return;
    _failure = reason;
    unawaited(close());
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    _closed = true;
    _startupTimer?.cancel();
    _seatTimer?.cancel();
    _silenceTimer?.cancel();
    _current?.close();
    _current = null;
    _httpClient?.close(force: true);
    if (!_first.isCompleted) _first.completeError(NiconicoException(_failure ?? NiconicoFailure.sessionClosed));
    return _closing = _dispose();
  }

  Future<void> _dispose() async {
    try {
      await Future.wait<void>([
        if (_cancellation != null) _cancellation!.cancel(),
        if (_subscription != null) _subscription!.cancel(),
        if (_channel != null) _channel!.sink.close(1000),
      ]).timeout(closeTimeout);
      _cleanupSucceeded = true;
    } catch (_) {
      _cleanupSucceeded = false;
      _failure ??= NiconicoFailure.cleanup;
    } finally {
      _subscription = null;
      _cancellation = null;
      _channel = null;
      unawaited(_changes.close());
      _done.complete(_failure);
    }
  }
}
