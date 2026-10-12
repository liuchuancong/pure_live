import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_models.dart';
import 'package:live_sites/src/platforms/bilibili/danmaku/bilibili_mapper.dart';
import 'package:live_sites/src/platforms/bilibili/danmaku/bilibili_packet.dart';

/// A live danmaku session over a bilibili WebSocket.
///
/// Lifecycle: open → auth (op 7) → on accept (op 8, code 0) heartbeat
/// every 30 s → notices (op 5) decoded, inflated, mapped and broadcast.
/// A socket drop ends the session with an error on the stream — auto
/// reconnect belongs to the caller's supervisor, which owns the retry
/// policy.
final class BilibiliDanmakuSession implements LiveDanmakuSession {
  // Pre-comment: private named constructors cannot use the `new`
  // shorthand, so the traditional form stays by design.
  // ignore: unnecessary_type_name_in_constructor
  BilibiliDanmakuSession._(this._socket) {
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      _socket.add(BilibiliDanmakuProtocol.heartbeat());
    });
    _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  final WebSocket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  late final Timer _heartbeat;
  bool _authed = false;
  bool _closed = false;

  /// Popularity read from the last heartbeat reply, for diagnostics.
  int popularity = 0;

  /// Whether the gateway accepted the auth packet.
  bool get isAuthed => _authed;

  /// Opens and authenticates a session for `args`.
  static Future<BilibiliDanmakuSession> connect(BilibiliDanmakuArgs args) async {
    final socket = await WebSocket.connect(args.server);
    final session = BilibiliDanmakuSession._(socket);
    socket.add(BilibiliDanmakuProtocol.auth(args));
    return session;
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(dynamic data) {
    if (_closed || data is! List<int>) {
      return;
    }
    try {
      for (final (:operation, :body) in BilibiliDanmakuProtocol.decode(data)) {
        switch (operation) {
          case BilibiliDanmakuProtocol.opAuthReply:
            final code = _authCode(body);
            if (code == 0) {
              _authed = true;
            } else {
              _fail(StateError('bilibili danmaku auth rejected: code $code'), StackTrace.current);
              return;
            }
          case BilibiliDanmakuProtocol.opHeartbeatReply when body.length >= 4:
            popularity = ByteData.sublistView(body).getUint32(0);
          case BilibiliDanmakuProtocol.opNotice:
            final notice = jsonDecode(utf8.decode(body, allowMalformed: true));
            final message = BilibiliDanmakuMapper.notice(notice);
            if (message != null) {
              _messages.add(message);
            }
        }
      }
    } on FormatException catch (error, stackTrace) {
      _fail(error, stackTrace);
    }
  }

  int _authCode(Uint8List body) {
    final text = utf8.decode(body, allowMalformed: true).trim();
    if (text.isEmpty) {
      return 0;
    }
    final reply = jsonDecode(text);
    return reply is Map<String, Object?> ? (reply['code'] as num?)?.toInt() ?? -1 : -1;
  }

  void _fail(Object error, StackTrace stackTrace) {
    if (_closed) {
      return;
    }
    _closed = true;
    _heartbeat.cancel();
    _messages.addError(error, stackTrace);
    unawaited(_messages.close());
    unawaited(_socket.close());
  }

  void _done() {
    if (_closed) {
      return;
    }
    _closed = true;
    _heartbeat.cancel();
    unawaited(_messages.close());
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _heartbeat.cancel();
    await _messages.close();
    await _socket.close();
  }
}
