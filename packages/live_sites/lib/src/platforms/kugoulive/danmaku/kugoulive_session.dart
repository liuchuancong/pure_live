import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_danmaku.dart';
import 'package:live_sites/src/registry/site_ids/site_ids.dart';

/// A Kugou Live chat session: the scheduler's hosts and token, then the room's
/// protobuf-over-WebSocket chat, joined as the website's room page does.
///
/// - Before the socket, the scheduler (`socket_scheduler/…/address.jsonp`,
///   signed) is asked for the room's chat hosts and token; the page's backoff
///   retries it, and a refusal or three failures end the stream.
/// - Every socket logs in (201) and is joined when the status frame accepts it;
///   a login unanswered within [KugouLiveDanmakuProtocol.joinTimeout] ends the
///   stream, as does a refused login or a socket silent for 90 s.
/// - The binary heartbeat goes every 10 s; a gift whose envelope asks for one is
///   acknowledged, and a gift the server sends again (the same `msgId`) is
///   reported once.
/// - Unlike the reference, which folds a reconnect ladder and a token-age
///   refresh into the connection, this build ends the stream on those
///   conditions — the caller's supervisor reconnects, which re-asks the
///   scheduler (the same division as the looklive and seventeenlive sessions).
///
/// Archived from the reference and not run against the live service.
final class KugouLiveDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the looklive session).
  // ignore: unnecessary_type_name_in_constructor
  KugouLiveDanmakuSession._(this._args, this._socket, this._grant, this._sid, this._deviceNo) {
    _send(KugouLiveDanmakuProtocol.login(roomId: _args.roomId, token: _grant.token, sid: _sid, deviceNo: _deviceNo));
    _joinTimer = Timer(KugouLiveDanmakuProtocol.joinTimeout, () {
      if (!_joined) _fail(const SiteApiChangedError('kugoulive chat: login timed out'));
    });
    _heartbeat = Timer.periodic(
      KugouLiveDanmakuProtocol.heartbeatInterval,
      (_) => _send(KugouLiveDanmakuProtocol.heartbeat()),
    );
    _resetSilence();
    _subscription = _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  /// Opens a session for [args] over [http]: the scheduler first, then the
  /// first host whose socket opens. [random] draws the login's session and
  /// device ids, [now] the scheduler's clock (tests).
  static Future<KugouLiveDanmakuSession> connect(
    LiveHttp http,
    KugouLiveDanmakuArgs args, {
    Random? random,
    DateTime Function()? now,
  }) async {
    final source = random ?? Random.secure();
    final clock = now ?? DateTime.now;
    final room =
        KugouLiveDanmakuProtocol.checkedRoom(args.roomId) ??
        (throw const SiteNotFoundError('kugoulive: not a room id'));
    final grant = await _dispatch(http, room, clock);
    Object? failure;
    for (final endpoint in grant.endpoints) {
      try {
        final socket = await WebSocket.connect(endpoint.toString(), headers: KugouLiveDanmakuProtocol.socketHeaders);
        return KugouLiveDanmakuSession._(
          KugouLiveDanmakuArgs(room),
          socket,
          grant,
          KugouLiveDanmakuProtocol.uuid(source),
          KugouLiveDanmakuProtocol.uuid(source),
        );
      } on Object catch (error) {
        failure = error;
      }
    }
    throw failure is SiteError ? failure : const SiteApiChangedError('kugoulive chat: no chat host reachable');
  }

  /// Asks the scheduler for [room]'s hosts and token: [dispatchRetryDelays]'s
  /// retries, the page's waits apart. A refusal is thrown as it is; every
  /// failure then becomes a `SiteError`.
  static Future<KugouLiveChatGrant> _dispatch(LiveHttp http, String room, DateTime Function() now) async {
    Object? failure;
    for (var attempt = 0; attempt <= dispatchRetryDelays.length; attempt++) {
      if (attempt > 0) await Future<void>.delayed(dispatchRetryDelays[attempt - 1]);
      try {
        final response = await http.send(
          LiveRequest.get(
            KugouLiveDanmakuProtocol.dispatchUrl(room, now: now()),
            headers: KugouLiveDanmakuProtocol.dispatchHeaders(room),
            site: SiteIds.kugouLive,
          ),
        );
        return KugouLiveDanmakuProtocol.grant(response.text, status: response.statusCode);
      } on KugouLiveDispatchRefusal {
        rethrow;
      } on Object catch (error) {
        failure = error;
      }
    }
    throw failure is SiteError ? failure : const SiteApiChangedError('kugoulive chat: dispatch failed');
  }

  /// The page's waits before the second and third scheduler request.
  static const List<Duration> dispatchRetryDelays = [Duration(milliseconds: 1500), Duration(milliseconds: 4500)];

  static const Duration _silenceTimeout = Duration(seconds: 90);

  final KugouLiveDanmakuArgs _args;
  final WebSocket _socket;
  final KugouLiveChatGrant _grant;
  final String _sid;
  final String _deviceNo;
  final _messages = StreamController<LiveMessage>.broadcast();
  late final StreamSubscription<Object?> _subscription;
  late final Timer _joinTimer;
  late final Timer _heartbeat;
  Timer? _silence;
  bool _joined = false;
  bool _closed = false;
  final LinkedHashSet<String> _gifts = LinkedHashSet();

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(Object? data) {
    if (_closed) return;
    _resetSilence();
    final frame = KugouLiveDanmakuProtocol.decode(data, roomId: _args.roomId);
    if (frame.ack case final ack?) _send(ack);
    if (frame.refusal case final refusal?) {
      _fail(SiteApiChangedError('kugoulive chat: $refusal'));
      return;
    }
    if (frame.joined) {
      _joined = true;
      _joinTimer.cancel();
    }
    for (final message in frame.messages) {
      if (_closed) return;
      if (message.type == LiveMessageType.gift && !_firstGift(message.id ?? '')) continue;
      _messages.add(message);
    }
  }

  void _send(List<int> bytes) {
    if (!_closed) _socket.add(bytes);
  }

  static const int _giftsKept = 256;

  /// Whether the gift [messageId] was not reported yet (and marks it); a gift
  /// without one always is.
  bool _firstGift(String messageId) {
    if (messageId.isEmpty) return true;
    if (!_gifts.add(messageId)) return false;
    if (_gifts.length > _giftsKept) _gifts.remove(_gifts.first);
    return true;
  }

  void _resetSilence() {
    _silence?.cancel();
    _silence = Timer(_silenceTimeout, () => _fail(const SiteApiChangedError('kugoulive chat: socket silent')));
  }

  void _fail(Object error, [StackTrace? stack]) {
    if (_closed) return;
    _closed = true;
    _joinTimer.cancel();
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
    _joinTimer.cancel();
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
    _joinTimer.cancel();
    _heartbeat.cancel();
    _silence?.cancel();
    await _subscription.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
