import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/looklive/danmaku/looklive_danmaku.dart';
import 'package:live_sites/src/registry/site_ids/site_ids.dart';

/// A LOOK (NetEase Yunxin) chat session: an anonymous guest in the room's
/// Yunxin chatroom, joined the way LOOK's website does.
///
/// - The room's chat-server endpoints (resolved by the site) are tried in
///   order; each handshake first asks the server for a socket.io session (a
///   GET) and then opens its WebSocket.
/// - When the session opens (`1::`) the guest logs in; the login's answer joins.
/// - The server's `2::` is echoed, the link heartbeat goes out every six ticks
///   (~3 minutes), and a socket silent for 90 s is treated as dead.
/// - Unlike the reference, which folds a reconnect ladder into the connection,
///   this build ends the stream on a drop, a refused login, a kick or silence —
///   the caller's supervisor reconnects, which re-resolves the servers and the
///   socket.io session (the same division as the kick and baidulive sessions).
/// - Only chat and gifts are reported; the chat has no audience figure.
///
/// Archived from the reference and not run against the live service.
final class LookLiveDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the kick session).
  // ignore: unnecessary_type_name_in_constructor
  LookLiveDanmakuSession._(this._args, this._socket, this._guest) {
    _heartbeat = Timer.periodic(LookLiveDanmakuProtocol.heartbeatInterval, (_) => _tick());
    _joinTimer = Timer(LookLiveDanmakuProtocol.joinTimeout, () {
      if (!_joined) _fail(const SiteApiChangedError('looklive chat: login timed out'));
    });
    _resetSilence();
    _subscription = _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  /// Opens a session for [args] over [http] on the first [endpoints] whose
  /// handshake answers.
  static Future<LookLiveDanmakuSession> connect(
    LookLiveDanmakuArgs args,
    LiveHttp http,
    List<Uri> endpoints, {
    Random? random,
  }) async {
    final guest = LookLiveGuest.random(random ?? Random.secure());
    Object? failure;
    for (final endpoint in endpoints) {
      try {
        final socket = await _openSocket(args.roomId, http, endpoint);
        return LookLiveDanmakuSession._(args, socket, guest);
      } on Object catch (error) {
        failure = error;
      }
    }
    throw failure is SiteError ? failure : const SiteApiChangedError('looklive chat: no chat server reachable');
  }

  static Future<WebSocket> _openSocket(String roomId, LiveHttp http, Uri endpoint) async {
    final handshake = endpoint.replace(
      scheme: endpoint.isScheme('ws') ? 'http' : 'https',
      path: '/socket.io/1/',
      query: 't=${DateTime.now().millisecondsSinceEpoch}',
    );
    final response = await http.send(
      LiveRequest.get(
        handshake,
        headers: {'origin': LookLiveDanmakuProtocol.origin, 'referer': LookLiveDanmakuProtocol.roomUrl(roomId)},
        site: SiteIds.looklive,
      ),
    );
    final sessionId = LookLiveDanmakuProtocol.sessionOf(response.text, status: response.statusCode);
    final socket = await WebSocket.connect(
      LookLiveDanmakuProtocol.socketUrl(endpoint, sessionId).toString(),
      headers: LookLiveDanmakuProtocol.socketHeaders,
    );
    return socket;
  }

  final LookLiveDanmakuArgs _args;
  final WebSocket _socket;
  final LookLiveGuest _guest;
  final _messages = StreamController<LiveMessage>.broadcast();
  late final StreamSubscription<Object?> _subscription;
  late final Timer _heartbeat;
  late final Timer _joinTimer;
  Timer? _silence;
  int _serial = 0;
  int _ticks = 0;
  bool _loggedIn = false;
  bool _joined = false;
  bool _closed = false;

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _tick() {
    if (_closed) return;
    _ticks++;
    if (_ticks % LookLiveDanmakuProtocol.ticksPerHeartbeat == 0) _socket.add(LookLiveDanmakuProtocol.heartbeat);
  }

  void _onData(Object? data) {
    if (_closed) return;
    _resetSilence();
    final frame = LookLiveDanmakuProtocol.decode(data, anonymousMode: _args.anonymousMode);
    frame.replies.forEach(_socket.add);
    if (frame.opened && !_loggedIn) {
      _loggedIn = true;
      _socket.add(LookLiveDanmakuProtocol.login(chatroomId: _args.chatroomId, guest: _guest, serial: ++_serial));
    }
    frame.messages.forEach(_messages.add);
    if (frame.joined && !_joined) {
      _joined = true;
      _joinTimer.cancel();
    }
    if (frame.refusal case final code?) {
      _fail(SiteApiChangedError('looklive chat: login refused ($code)'));
    } else if (frame.kicked case final reason?) {
      _fail(SiteApiChangedError('looklive chat: kicked (${LookLiveDanmakuProtocol.kickReasons[reason]})'));
    } else if (frame.dropped) {
      _fail(const SiteApiChangedError('looklive chat: server dropped the session'));
    }
  }

  void _resetSilence() {
    _silence?.cancel();
    _silence = Timer(
      const Duration(seconds: 90),
      () => _fail(const SiteApiChangedError('looklive chat: socket silent')),
    );
  }

  void _fail(Object error, [StackTrace? stack]) {
    if (_closed) return;
    _closed = true;
    _heartbeat.cancel();
    _joinTimer.cancel();
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
    _joinTimer.cancel();
    _silence?.cancel();
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _heartbeat.cancel();
    _joinTimer.cancel();
    _silence?.cancel();
    await _subscription.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
