import 'dart:async';
import 'dart:io';

import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/bigo/danmaku/bigo_danmaku.dart';

/// A Bigo chat session: one anonymous socket through the page's handshake.
///
/// Lifecycle: open the socket, answer the server's challenge, log in as the
/// [BigoChatVisitor] a second later, enter the room on an accepted login, and
/// ask the audience on an accepted entry — the entry joins the room. A ping
/// goes out every 10 s once logged in. Chat, the concurrent audience and gifts
/// are reported; a gift waits up to [BigoDanmakuProtocol.giftSenderWait] for
/// the gift line that names its sender and is shown with the name then, or
/// without it once the wait ends.
///
/// An error on the stream ends the session and the caller's supervisor owns any
/// reconnect — the same division as the soop and showroom sessions. So an idle
/// room (no broadcast), a refused login or entry, or no entry within the join
/// limit closes the session with an error; the visitor is asked for fresh by the
/// site on the next connect.
///
/// Archived from the reference and not run against the live service.
final class BigoDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the showroom session).
  // ignore: unnecessary_type_name_in_constructor
  BigoDanmakuSession._(this._visitor, this._ownerId, this._roomId, this._socket, this._now) {
    _join = Timer(BigoDanmakuProtocol.joinTimeout, () {
      _fail(const SiteNotFoundError('bigo chat: join timed out'), StackTrace.current);
    });
    _heartbeat = Timer.periodic(BigoDanmakuProtocol.heartbeatInterval, (_) {
      if (!_closed && _loginSent) _socket.add(BigoDanmakuProtocol.ping(_now()));
    });
    _subscription = _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  final BigoChatVisitor _visitor;
  final int _ownerId;
  final String _roomId;
  final WebSocket _socket;
  final DateTime Function() _now;
  final _messages = StreamController<LiveMessage>.broadcast();
  late final Timer _heartbeat;
  Timer? _join;
  Timer? _loginTimer;
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;
  bool _answered = false;
  bool _loginSent = false;
  bool _entering = false;
  bool _joined = false;
  final List<_PendingGift> _gifts = [];

  /// Opens a session for room [_roomId] (owned by [ownerId]) as [visitor].
  static Future<BigoDanmakuSession> connect(
    BigoChatVisitor visitor, {
    required int ownerId,
    required String roomId,
    DateTime Function()? now,
  }) async {
    final socket = await WebSocket.connect(
      BigoDanmakuProtocol.endpoint.toString(),
      headers: BigoDanmakuProtocol.socketHeaders,
    );
    return BigoDanmakuSession._(visitor, ownerId, roomId, socket, now ?? DateTime.now);
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(dynamic data) {
    if (_closed) {
      return;
    }
    final frame = BigoDanmakuProtocol.decode(data, roomId: _roomId);
    if (frame.refusal case final refusal?) {
      _fail(SiteNotFoundError('bigo chat: $refusal'), StackTrace.current);
      return;
    }
    if (frame.challenge case final challenge? when !_answered) {
      _answered = true;
      _socket.add(BigoDanmakuProtocol.answer(challenge, _now()));
      _loginTimer = Timer(BigoDanmakuProtocol.loginDelay, () {
        _loginTimer = null;
        if (_closed) return;
        _loginSent = true;
        _socket.add(BigoDanmakuProtocol.login(_visitor));
      });
    }
    if (frame.loggedIn && _loginSent && !_entering) {
      _entering = true;
      _socket.add(BigoDanmakuProtocol.enter(_roomId, _visitor, _now()));
    }
    if (frame.idle) {
      _fail(SiteNotFoundError('bigo chat: no broadcast in room $_roomId'), StackTrace.current);
      return;
    }
    if (frame.entered && !_joined) {
      _joined = true;
      _join?.cancel();
      _socket.add(BigoDanmakuProtocol.users(_ownerId, _roomId, _now()));
    }
    if (frame.giftSender case final sender?) _named(sender);
    for (final message in frame.messages) {
      if (_closed) return;
      if (message.type == LiveMessageType.gift && (message.userId?.isNotEmpty ?? false)) {
        _waitForSender(message);
      } else {
        _messages.add(message);
      }
    }
  }

  /// Holds a gift until its line names the sender, or reports it nameless when
  /// the wait ends.
  void _waitForSender(LiveMessage gift) {
    final entry = _PendingGift(gift);
    entry.timer = Timer(BigoDanmakuProtocol.giftSenderWait, () {
      if (_gifts.remove(entry) && !_closed) _messages.add(gift);
    });
    _gifts.add(entry);
  }

  /// Reports the oldest waiting gift of [sender]'s account with the name the
  /// gift line gives.
  void _named(BigoGiftSender sender) {
    final index = _gifts.indexWhere((entry) => entry.gift.userId == sender.userId);
    if (index < 0) return;
    final entry = _gifts.removeAt(index);
    entry.timer?.cancel();
    if (_closed) return;
    final gift = entry.gift;
    _messages.add(
      LiveMessage(
        type: gift.type,
        userName: sender.name,
        userId: gift.userId,
        message: gift.message,
        color: gift.color,
        id: gift.id,
        sentAt: gift.sentAt,
        data: gift.data,
      ),
    );
  }

  void _teardown() {
    _closed = true;
    _heartbeat.cancel();
    _join?.cancel();
    _loginTimer?.cancel();
    for (final entry in _gifts) {
      entry.timer?.cancel();
    }
    _gifts.clear();
  }

  void _fail(Object error, StackTrace stack) {
    if (_closed) {
      return;
    }
    _teardown();
    if (!_messages.isClosed) {
      _messages.addError(error, stack);
      unawaited(_messages.close());
    }
  }

  void _done() {
    if (_closed) {
      return;
    }
    _teardown();
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _teardown();
    await _subscription?.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}

/// A gift waiting for its line's sender name.
final class _PendingGift {
  new(this.gift);

  final LiveMessage gift;
  Timer? timer;
}
