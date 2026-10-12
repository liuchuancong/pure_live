import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/picarto/danmaku/picarto_danmaku.dart';

/// A Picarto danmaku session: a chat token from the GraphQL API over `http`,
/// then the chat socket.
///
/// - A token is asked at every open, up to three times (0.5 s and 1 s apart);
///   without one the session ends with an error on the stream. Tokens do not
///   expire, so reconnects reuse one, as the site's client does.
/// - An open socket counts as joined (the server sends no welcome); the
///   keep-alive goes out every 50 s and the server answers it.
/// - A refused token (`JWT_TOKEN`) is replaced by a new one and the socket
///   reopened, at most three times; then the session ends.
///
/// Chat, chip tips (as super chats), system/raid/subscription notices, deleted
/// and cleared messages (as recalls) and the audience are reported by
/// [PicartoDanmakuProtocol.decode]. Reconnecting beyond a refused token belongs
/// to the caller's supervisor, which owns the retry policy — the same division
/// as the showroom and soop sessions. Archived from the reference, not run live.
final class PicartoDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the showroom session).
  // ignore: unnecessary_type_name_in_constructor
  PicartoDanmakuSession._(this._http, this._channelName, this._channelId);

  /// Token requests per attempt to get one.
  static const int _tokenAttempts = 3;

  /// Longest wait for one token answer.
  static const Duration _tokenTimeout = Duration(seconds: 5);

  /// The step growing between token attempts (0.5 s, then 1 s).
  static const Duration _retryDelay = Duration(milliseconds: 500);

  /// Refused tokens replaced per connection.
  static const int _maxTokenRefreshes = 3;

  final LiveHttp _http;
  final String _channelName;
  final int _channelId;
  final _messages = StreamController<LiveMessage>.broadcast();
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  bool _closed = false;
  bool _refreshing = false;
  int _refreshes = 0;

  /// Opens a session for channel [channelName] (id [channelId]).
  static Future<PicartoDanmakuSession> connect(
    LiveHttp http, {
    required String channelName,
    required int channelId,
  }) async {
    final session = PicartoDanmakuSession._(http, channelName, channelId);
    try {
      await session._open();
    } on Object {
      await session.close();
      rethrow;
    }
    return session;
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  /// Gets a token and opens the socket on it, (re)arming the keep-alive.
  Future<void> _open() async {
    final token = await _token();
    if (token == null) {
      throw SiteNotFoundError('picarto chat: no token for $_channelName');
    }
    final socket = await WebSocket.connect(
      PicartoDanmakuProtocol.endpoint(token).toString(),
      headers: PicartoDanmakuProtocol.handshakeHeaders,
    );
    _socket = socket;
    _subscription = socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(PicartoDanmakuProtocol.heartbeatInterval, (_) {
      final socket = _socket;
      if (!_closed && socket != null) socket.add(PicartoDanmakuProtocol.heartbeat);
    });
  }

  /// A token for the channel: up to [_tokenAttempts] requests, or null when
  /// none gave one or the session closed.
  Future<String?> _token() async {
    for (var attempt = 0; attempt < _tokenAttempts; attempt++) {
      if (attempt > 0) await Future<void>.delayed(_retryDelay * attempt);
      if (_closed) return null;
      try {
        final response = await _http.send(
          LiveRequest.json(
            PicartoDanmakuProtocol.tokenEndpoint,
            body: PicartoDanmakuProtocol.tokenBody(_channelName),
            headers: PicartoDanmakuProtocol.handshakeHeaders,
            site: SiteIds.picarto,
            timeout: _tokenTimeout,
          ),
        );
        final token = PicartoDanmakuProtocol.token(jsonDecode(response.text));
        if (token != null) return token;
      } on Object {
        // A failed or unparseable answer is retried; the last attempt decides.
      }
    }
    return null;
  }

  void _onData(dynamic data) {
    if (_closed) {
      return;
    }
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null) {
      return;
    }
    final frame = PicartoDanmakuProtocol.decode(text, channelId: _channelId, channelName: _channelName);
    frame.messages.forEach(_messages.add);
    if (frame.tokenRefused) {
      unawaited(_refused());
    }
  }

  /// Replaces a refused token and reopens, without a notice.
  Future<void> _refused() async {
    if (_closed || _refreshing) {
      return;
    }
    _refreshing = true;
    try {
      if (_refreshes >= _maxTokenRefreshes) {
        _fail(const SiteNotFoundError('picarto chat: token refused'), StackTrace.current);
        return;
      }
      _refreshes++;
      final old = _subscription;
      final oldSocket = _socket;
      _subscription = null;
      _socket = null;
      _heartbeat?.cancel();
      await old?.cancel();
      await oldSocket?.close();
      await _open();
    } on Object catch (error, stack) {
      _fail(error, stack);
    } finally {
      _refreshing = false;
    }
  }

  void _fail(Object error, StackTrace stack) {
    if (_closed) {
      return;
    }
    _closed = true;
    _heartbeat?.cancel();
    if (!_messages.isClosed) {
      _messages.addError(error, stack);
      unawaited(_messages.close());
    }
  }

  void _done() {
    if (_closed) {
      return;
    }
    _closed = true;
    _heartbeat?.cancel();
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _heartbeat?.cancel();
    await _subscription?.cancel();
    await _socket?.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
