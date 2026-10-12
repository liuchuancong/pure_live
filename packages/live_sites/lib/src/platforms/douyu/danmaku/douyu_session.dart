import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/douyu/danmaku/douyu_danmaku.dart';

/// A Douyu danmaku session over one raw TCP socket.
///
/// Douyu's chat is not a WebSocket: a plain socket to
/// [DouyuDanmakuProtocol.host]:[DouyuDanmakuProtocol.port] carries the same
/// length-prefixed packets as a raw byte stream, so a read may split a packet
/// or carry several. This session buffers incoming bytes, cuts off each
/// complete packet (by its 4-byte little-endian length prefix), and hands that
/// packet to [DouyuDanmakuProtocol.read] for chat, super chats, gifts and the
/// broadcast-end. On open it sends the join packets and then a `mrkl` heartbeat
/// every 45 s; Douyu answers no join ack, so an open socket is joined. An error
/// or a closed socket ends the session with an error on the stream;
/// reconnecting belongs to the caller's supervisor, which owns the retry
/// policy — the same division as the other sessions.
///
/// Archived from the reference and not run against the live service.
final class DouyuDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the showroom session).
  // ignore: unnecessary_type_name_in_constructor
  DouyuDanmakuSession._(this._roomId, this._socket) {
    _heartbeat = Timer.periodic(DouyuDanmakuProtocol.heartbeatInterval, (_) {
      if (!_closed) _socket.add(DouyuDanmakuProtocol.heartbeat());
    });
    _subscription = _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  /// The largest packet this session will buffer before declaring the stream
  /// desynchronised (a bogus length prefix).
  static const int _maxPacket = 1 << 20;

  final String _roomId;
  final Socket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  late final Timer _heartbeat;
  StreamSubscription<List<int>>? _subscription;
  final List<int> _pending = <int>[];
  bool _closed = false;

  /// Opens a session for room [roomId].
  static Future<DouyuDanmakuSession> connect(String roomId) async {
    final socket = await Socket.connect(DouyuDanmakuProtocol.host, DouyuDanmakuProtocol.port);
    final session = DouyuDanmakuSession._(roomId, socket);
    DouyuDanmakuProtocol.joinPackets(roomId).forEach(socket.add);
    return session;
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(List<int> chunk) {
    if (_closed) {
      return;
    }
    _pending.addAll(chunk);
    // Cut complete packets off the front of the buffer; an incomplete tail
    // waits for the next read.
    while (true) {
      if (_pending.length < 4) return;
      final length = _pending[0] | (_pending[1] << 8) | (_pending[2] << 16) | (_pending[3] << 24);
      if (length < 9 || length > _maxPacket) {
        _fail(const SiteApiChangedError('douyu danmaku: stream desynchronised'), StackTrace.current);
        return;
      }
      final total = 4 + length;
      if (_pending.length < total) return;
      final packet = Uint8List.fromList(_pending.sublist(0, total));
      _pending.removeRange(0, total);
      final (:messages, :ended) = DouyuDanmakuProtocol.read(packet, roomId: _roomId);
      messages.forEach(_messages.add);
      if (ended) {
        _fail(const SiteNotFoundError('douyu: ${DouyuDanmakuProtocol.broadcastEnded}'), StackTrace.current);
        return;
      }
    }
  }

  void _fail(Object error, StackTrace stack) {
    if (_closed) {
      return;
    }
    _closed = true;
    _heartbeat.cancel();
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
    _heartbeat.cancel();
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
    _heartbeat.cancel();
    await _subscription?.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
