import 'dart:async';
import 'dart:io';

import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_danmaku.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_sign.dart';

/// A Douyin chat session: an anonymous socket to the web IM edge, joined as the
/// website's web client does.
///
/// - The connection is signed with the X-Bogus [DouyinSign] of the broadcast and
///   opened on the first of [DouyinDanmakuProtocol.hosts] whose handshake works.
/// - An open socket counts as joined; an `hb` frame follows at once and every 10
///   s; a socket silent for 45 s ends the stream.
/// - A frame that asks for it is acknowledged before its messages are reported;
///   chat of another broadcast is dropped.
/// - Unlike the reference, which folds a reconnect ladder and a follow-the-
///   streamer refresh into the connection, this build ends the stream on an
///   error, a close or silence — the caller's supervisor reconnects (the same
///   division as the looklive and seventeenlive sessions).
///
/// Archived from the reference and not run against the live service.
final class DouyinDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the looklive session).
  // ignore: unnecessary_type_name_in_constructor
  DouyinDanmakuSession._(this._args, this._socket) {
    _heartbeat = Timer.periodic(
      DouyinDanmakuProtocol.heartbeatInterval,
      (_) => _send(DouyinDanmakuProtocol.heartbeat()),
    );
    _send(DouyinDanmakuProtocol.heartbeat());
    _resetSilence();
    _subscription = _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  /// Opens a session for [args], trying the web IM edges in order with [signer]
  /// (a fresh one when not given).
  static Future<DouyinDanmakuSession> connect(DouyinDanmakuArgs args, {DouyinSign? signer}) async {
    final webSigner = signer ?? DouyinSign();
    final signature = webSigner.danmakuSignature(roomId: args.roomId, userUniqueId: args.userId);
    final endpoints = DouyinDanmakuProtocol.endpoints(args, signature: signature, now: DateTime.now());
    Object? failure;
    for (final endpoint in endpoints) {
      try {
        final socket = await WebSocket.connect(endpoint.toString(), headers: args.headers);
        return DouyinDanmakuSession._(args, socket);
      } on Object catch (error) {
        failure = error;
      }
    }
    throw failure is SiteError ? failure : const SiteApiChangedError('douyin chat: no im edge reachable');
  }

  final DouyinDanmakuArgs _args;
  final WebSocket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  late final StreamSubscription<Object?> _subscription;
  late final Timer _heartbeat;
  Timer? _silence;
  bool _closed = false;

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(Object? data) {
    if (_closed) return;
    _resetSilence();
    // Douyin only sends binary frames.
    if (data is! List<int>) return;
    final frame = DouyinDanmakuProtocol.decode(data, roomId: _args.roomId);
    if (frame.ack case final ack?) _send(ack);
    frame.messages.forEach(_messages.add);
  }

  void _send(List<int> bytes) {
    if (!_closed) _socket.add(bytes);
  }

  void _resetSilence() {
    _silence?.cancel();
    _silence = Timer(
      DouyinDanmakuProtocol.inactivityTimeout,
      () => _fail(const SiteApiChangedError('douyin chat: socket silent')),
    );
  }

  void _fail(Object error, [StackTrace? stack]) {
    if (_closed) return;
    _closed = true;
    _heartbeat.cancel();
    _silence?.cancel();
    unawaited(_subscription.cancel());
    unawaited(_socket.close());
    if (!_messages.isClosed) {
      _messages.addError(error, stack ?? StackTrace.current);
      unawaited(_messages.close());
    }
  }

  void _done() {
    if (_closed) return;
    _closed = true;
    _heartbeat.cancel();
    _silence?.cancel();
    unawaited(_subscription.cancel());
    unawaited(_socket.close());
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _heartbeat.cancel();
    _silence?.cancel();
    await _subscription.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
